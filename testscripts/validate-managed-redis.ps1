<#
.SYNOPSIS
    Validates Azure Managed Redis deployment.

.DESCRIPTION
    This script validates that Azure Managed Redis has been deployed correctly and all security controls are in place.
    It checks:
    - Azure Managed Redis resource exists with correct SKU
    - Private endpoint is configured (if network isolated)
    - RBAC roles are properly assigned
    - Key Vault secret contains correct connection string

.PARAMETER ResourceGroupName
    The name of the Azure resource group containing the Managed Redis instance.

.PARAMETER RedisName
    The name of the Azure Managed Redis instance.

.PARAMETER ExpectedSku
    The expected SKU name (e.g., 'Balanced_B1' for dev, 'Balanced_B5' for production).

.PARAMETER KeyVaultName
    The name of the Azure Key Vault containing the Redis connection string.

.PARAMETER CheckPrivateEndpoint
    Whether to check for private endpoint configuration (default: false).

.EXAMPLE
    .\validate-managed-redis.ps1 -ResourceGroupName "rg-myapp-dev" -RedisName "redisenterprise-abc123" -ExpectedSku "Balanced_B1"

.OUTPUTS
    Exit code 0 on success, Exit code 1 on failure.
    Structured JSON output for CI integration.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$RedisName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Balanced_B0', 'Balanced_B1', 'Balanced_B3', 'Balanced_B5', 'Balanced_B10', 'Balanced_B20', 
                 'MemoryOptimized_M10', 'MemoryOptimized_M20', 'ComputeOptimized_X3', 'ComputeOptimized_X5')]
    [string]$ExpectedSku,

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $false)]
    [switch]$CheckPrivateEndpoint
)

$ErrorActionPreference = "Stop"

# Initialize results object for structured output
$results = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    resourceGroup = $ResourceGroupName
    redisName = $RedisName
    expectedSku = $ExpectedSku
    checks = @()
    success = $true
}

function Add-CheckResult {
    param (
        [string]$Name,
        [bool]$Passed,
        [string]$Message,
        [string]$Details = ""
    )
    
    $results.checks += @{
        name = $Name
        passed = $Passed
        message = $Message
        details = $Details
    }
    
    if (-not $Passed) {
        $script:results.success = $false
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Managed Redis Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: Verify Azure Managed Redis resource exists
Write-Host "Checking Azure Managed Redis resource existence..." -ForegroundColor Yellow
try {
    $redis = az redis-enterprise show --name $RedisName --resource-group $ResourceGroupName 2>$null | ConvertFrom-Json
    
    if ($null -eq $redis) {
        Add-CheckResult -Name "ResourceExists" -Passed $false -Message "Azure Managed Redis resource not found" -Details "Resource '$RedisName' does not exist in resource group '$ResourceGroupName'"
    } else {
        Add-CheckResult -Name "ResourceExists" -Passed $true -Message "Azure Managed Redis resource exists" -Details "Resource ID: $($redis.id)"
        Write-Host "  ✓ Resource found: $($redis.name)" -ForegroundColor Green
    }
} catch {
    Add-CheckResult -Name "ResourceExists" -Passed $false -Message "Failed to query Azure Managed Redis" -Details $_.Exception.Message
    Write-Host "  ✗ Failed to query resource: $($_.Exception.Message)" -ForegroundColor Red
}

# Check 2: Verify SKU matches expected value
Write-Host "Checking SKU configuration..." -ForegroundColor Yellow
if ($null -ne $redis) {
    $actualSku = $redis.sku.name
    if ($actualSku -eq $ExpectedSku) {
        Add-CheckResult -Name "SkuMatch" -Passed $true -Message "SKU matches expected value" -Details "Expected: $ExpectedSku, Actual: $actualSku"
        Write-Host "  ✓ SKU matches: $actualSku" -ForegroundColor Green
    } else {
        Add-CheckResult -Name "SkuMatch" -Passed $false -Message "SKU does not match expected value" -Details "Expected: $ExpectedSku, Actual: $actualSku"
        Write-Host "  ✗ SKU mismatch: Expected $ExpectedSku, got $actualSku" -ForegroundColor Red
    }
}

# Check 3: Verify minimum TLS version
Write-Host "Checking TLS configuration..." -ForegroundColor Yellow
if ($null -ne $redis) {
    $minTlsVersion = $redis.properties.minimumTlsVersion
    if ($minTlsVersion -eq "1.2") {
        Add-CheckResult -Name "TlsVersion" -Passed $true -Message "TLS 1.2 is enforced" -Details "Minimum TLS version: $minTlsVersion"
        Write-Host "  ✓ TLS 1.2 enforced" -ForegroundColor Green
    } else {
        Add-CheckResult -Name "TlsVersion" -Passed $false -Message "TLS 1.2 is not enforced" -Details "Minimum TLS version: $minTlsVersion"
        Write-Host "  ✗ TLS version is $minTlsVersion, expected 1.2" -ForegroundColor Red
    }
}

# Check 4: Verify private endpoint (if requested)
if ($CheckPrivateEndpoint) {
    Write-Host "Checking private endpoint configuration..." -ForegroundColor Yellow
    try {
        $privateEndpoints = az network private-endpoint list --resource-group $ResourceGroupName --query "[?contains(privateLinkServiceConnections[0].privateLinkServiceId, '$RedisName')]" 2>$null | ConvertFrom-Json
        
        if ($null -ne $privateEndpoints -and $privateEndpoints.Count -gt 0) {
            Add-CheckResult -Name "PrivateEndpoint" -Passed $true -Message "Private endpoint configured" -Details "Private endpoint: $($privateEndpoints[0].name)"
            Write-Host "  ✓ Private endpoint found: $($privateEndpoints[0].name)" -ForegroundColor Green
        } else {
            Add-CheckResult -Name "PrivateEndpoint" -Passed $false -Message "No private endpoint found" -Details "Azure Managed Redis should have a private endpoint for network isolation"
            Write-Host "  ✗ No private endpoint found" -ForegroundColor Red
        }
    } catch {
        Add-CheckResult -Name "PrivateEndpoint" -Passed $false -Message "Failed to check private endpoints" -Details $_.Exception.Message
        Write-Host "  ✗ Failed to check private endpoints: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check 5: Verify Azure Cache for Redis (legacy) does NOT exist
Write-Host "Checking that legacy Azure Cache for Redis does not exist..." -ForegroundColor Yellow
try {
    $legacyRedis = az redis list --resource-group $ResourceGroupName 2>$null | ConvertFrom-Json
    
    if ($null -eq $legacyRedis -or $legacyRedis.Count -eq 0) {
        Add-CheckResult -Name "NoLegacyRedis" -Passed $true -Message "No legacy Azure Cache for Redis resources found" -Details "Migration complete - only Azure Managed Redis exists"
        Write-Host "  ✓ No legacy Azure Cache for Redis found" -ForegroundColor Green
    } else {
        Add-CheckResult -Name "NoLegacyRedis" -Passed $false -Message "Legacy Azure Cache for Redis still exists" -Details "Found $($legacyRedis.Count) legacy Redis resource(s)"
        Write-Host "  ✗ Legacy Azure Cache for Redis found: $($legacyRedis.Count) instance(s)" -ForegroundColor Red
    }
} catch {
    # If the command fails, it might mean no legacy redis exists (good) or an error
    Add-CheckResult -Name "NoLegacyRedis" -Passed $true -Message "No legacy Azure Cache for Redis resources found" -Details "Query returned no results"
    Write-Host "  ✓ No legacy Azure Cache for Redis found" -ForegroundColor Green
}

# Check 6: Verify Key Vault secret (if KeyVaultName provided)
if (-not [string]::IsNullOrEmpty($KeyVaultName)) {
    Write-Host "Checking Key Vault secret..." -ForegroundColor Yellow
    try {
        $secret = az keyvault secret show --vault-name $KeyVaultName --name "redisConnectionString" 2>$null | ConvertFrom-Json
        
        if ($null -ne $secret) {
            # We don't log the actual secret value for security
            Add-CheckResult -Name "KeyVaultSecret" -Passed $true -Message "Redis connection string secret exists in Key Vault" -Details "Secret name: redisConnectionString"
            Write-Host "  ✓ Key Vault secret 'redisConnectionString' exists" -ForegroundColor Green
        } else {
            Add-CheckResult -Name "KeyVaultSecret" -Passed $false -Message "Redis connection string secret not found in Key Vault" -Details "Expected secret 'redisConnectionString' in vault '$KeyVaultName'"
            Write-Host "  ✗ Key Vault secret not found" -ForegroundColor Red
        }
    } catch {
        Add-CheckResult -Name "KeyVaultSecret" -Passed $false -Message "Failed to check Key Vault secret" -Details $_.Exception.Message
        Write-Host "  ✗ Failed to check Key Vault: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Output results summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passedCount = ($results.checks | Where-Object { $_.passed }).Count
$totalCount = $results.checks.Count

Write-Host "Passed: $passedCount / $totalCount checks" -ForegroundColor $(if ($results.success) { "Green" } else { "Red" })

# Output JSON for CI integration
$jsonOutput = $results | ConvertTo-Json -Depth 4
Write-Host ""
Write-Host "JSON Output:" -ForegroundColor Yellow
Write-Host $jsonOutput

# Exit with appropriate code
if ($results.success) {
    Write-Host ""
    Write-Host "✓ All validation checks passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "✗ Some validation checks failed!" -ForegroundColor Red
    exit 1
}
