#Requires -Version 7.0

<#
.SYNOPSIS
    Manages migration from Azure Cache for Redis to Azure Managed Redis.

.DESCRIPTION
    This script provides commands for migrating from Azure Cache for Redis to Azure Managed Redis.
    It supports the following operations:
    - Enable: Enables Azure Managed Redis by setting the feature flag
    - Disable: Disables Azure Managed Redis (rollback to Azure Cache for Redis)
    - Status: Shows current Redis configuration status
    - Validate: Runs validation tests on the Redis deployment
    
    The migration uses a feature flag approach where both services can coexist during transition.

.PARAMETER Action
    The action to perform: Enable, Disable, Status, or Validate

.PARAMETER Environment
    The target environment: dev or prod. Default is 'dev'.

.PARAMETER SkipProvision
    Skip the azd provision step (useful for testing the script)

.EXAMPLE
    # Check current status
    .\migrate-to-managed-redis.ps1 -Action Status

.EXAMPLE
    # Enable Azure Managed Redis in dev environment
    .\migrate-to-managed-redis.ps1 -Action Enable -Environment dev

.EXAMPLE
    # Rollback to Azure Cache for Redis
    .\migrate-to-managed-redis.ps1 -Action Disable

.EXAMPLE
    # Validate the deployment
    .\migrate-to-managed-redis.ps1 -Action Validate
#>

Param(
    [Parameter(Mandatory = $true, HelpMessage = "Action to perform: Enable, Disable, Status, or Validate")]
    [ValidateSet("Enable", "Disable", "Status", "Validate")]
    [String]$Action,
    
    [Parameter(Mandatory = $false, HelpMessage = "Target environment: dev or prod")]
    [ValidateSet("dev", "prod")]
    [String]$Environment = "dev",
    
    [Parameter(Mandatory = $false, HelpMessage = "Skip the azd provision step")]
    [switch]$SkipProvision
)

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ">>> $Message" -ForegroundColor Cyan
    Write-Host ""
}

function Get-CurrentSettings {
    Write-Step "Getting current environment settings..."
    
    $settings = @{
        UseManagedRedis = $null
        Environment = $null
        ResourceGroup = $null
    }
    
    try {
        $envValues = azd env get-values --output json 2>$null | ConvertFrom-Json
        
        if ($envValues.USE_MANAGED_REDIS) {
            $settings.UseManagedRedis = $envValues.USE_MANAGED_REDIS -eq "true"
        } else {
            $settings.UseManagedRedis = $false
        }
        
        if ($envValues.ENVIRONMENT) {
            $settings.Environment = $envValues.ENVIRONMENT
        } else {
            $settings.Environment = "dev"
        }
        
        if ($envValues.AZURE_RESOURCE_GROUP) {
            $settings.ResourceGroup = $envValues.AZURE_RESOURCE_GROUP
        }
    }
    catch {
        Write-Warning "Could not retrieve all environment settings. Some values may be defaults."
    }
    
    return $settings
}

function Show-Status {
    Write-Host "=============================================="
    Write-Host "Azure Redis Migration Status"
    Write-Host "=============================================="
    Write-Host ""
    
    $settings = Get-CurrentSettings
    
    Write-Host "Current Configuration:"
    Write-Host "  - USE_MANAGED_REDIS: $(if ($settings.UseManagedRedis) { 'true (Azure Managed Redis)' } else { 'false (Azure Cache for Redis)' })"
    Write-Host "  - ENVIRONMENT: $($settings.Environment)"
    Write-Host "  - AZURE_RESOURCE_GROUP: $($settings.ResourceGroup)"
    Write-Host ""
    
    if ($settings.UseManagedRedis) {
        Write-Host "Status: Azure Managed Redis is ENABLED" -ForegroundColor Green
    } else {
        Write-Host "Status: Azure Cache for Redis is being used (legacy)" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Enable-ManagedRedis {
    Write-Host "=============================================="
    Write-Host "Enable Azure Managed Redis"
    Write-Host "=============================================="
    
    Write-Step "Setting feature flag USE_MANAGED_REDIS to true..."
    azd env set USE_MANAGED_REDIS true
    
    Write-Step "Setting environment to $Environment..."
    azd env set ENVIRONMENT $Environment
    
    if (-not $SkipProvision) {
        Write-Step "Provisioning infrastructure with Azure Managed Redis..."
        Write-Host "This may take several minutes..."
        Write-Host ""
        
        azd provision
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Provisioning failed. Check the error messages above."
            Write-Host ""
            Write-Host "To rollback, run: .\migrate-to-managed-redis.ps1 -Action Disable"
            exit 1
        }
        
        Write-Step "Deploying application..."
        azd deploy
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Deployment had issues. You may need to run 'azd deploy' manually."
        }
    } else {
        Write-Host "Skipping provision step (--SkipProvision flag set)"
        Write-Host ""
        Write-Host "To complete the migration, run:"
        Write-Host "  azd provision"
        Write-Host "  azd deploy"
    }
    
    Write-Host ""
    Write-Host "=============================================="
    Write-Host "Migration Complete" -ForegroundColor Green
    Write-Host "=============================================="
    Write-Host ""
    Write-Host "Azure Managed Redis has been enabled."
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Run validation: .\migrate-to-managed-redis.ps1 -Action Validate"
    Write-Host "  2. Test your application"
    Write-Host "  3. Monitor Application Insights for any Redis-related errors"
    Write-Host ""
    Write-Host "To rollback if needed: .\migrate-to-managed-redis.ps1 -Action Disable"
    Write-Host ""
}

function Disable-ManagedRedis {
    Write-Host "=============================================="
    Write-Host "Disable Azure Managed Redis (Rollback)"
    Write-Host "=============================================="
    
    Write-Step "Setting feature flag USE_MANAGED_REDIS to false..."
    azd env set USE_MANAGED_REDIS false
    
    if (-not $SkipProvision) {
        Write-Step "Provisioning infrastructure with Azure Cache for Redis..."
        Write-Host "This may take several minutes..."
        Write-Host ""
        
        azd provision
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Provisioning failed. Check the error messages above."
            exit 1
        }
        
        Write-Step "Deploying application..."
        azd deploy
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Deployment had issues. You may need to run 'azd deploy' manually."
        }
    } else {
        Write-Host "Skipping provision step (--SkipProvision flag set)"
        Write-Host ""
        Write-Host "To complete the rollback, run:"
        Write-Host "  azd provision"
        Write-Host "  azd deploy"
    }
    
    Write-Host ""
    Write-Host "=============================================="
    Write-Host "Rollback Complete" -ForegroundColor Green
    Write-Host "=============================================="
    Write-Host ""
    Write-Host "Azure Cache for Redis has been restored."
    Write-Host ""
}

function Invoke-Validation {
    Write-Host "=============================================="
    Write-Host "Validate Redis Deployment"
    Write-Host "=============================================="
    
    $settings = Get-CurrentSettings
    
    if (-not $settings.ResourceGroup) {
        Write-Error "Resource group not found in environment settings."
        Write-Error "Please run 'azd provision' first or set AZURE_RESOURCE_GROUP."
        exit 1
    }
    
    Write-Step "Running validation script..."
    
    $scriptPath = Join-Path $PSScriptRoot "validate-managed-redis.ps1"
    
    if (Test-Path $scriptPath) {
        & $scriptPath -ResourceGroupName $settings.ResourceGroup -UseManagedRedis $settings.UseManagedRedis
    } else {
        Write-Error "Validation script not found at: $scriptPath"
        exit 1
    }
}

# Main script execution
switch ($Action) {
    "Enable" {
        Enable-ManagedRedis
    }
    "Disable" {
        Disable-ManagedRedis
    }
    "Status" {
        Show-Status
    }
    "Validate" {
        Invoke-Validation
    }
}
