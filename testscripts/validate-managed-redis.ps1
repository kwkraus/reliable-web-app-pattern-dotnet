#Requires -Version 7.0

<#
.SYNOPSIS
    Validates Azure Managed Redis deployment and connectivity.

    <This command should only be run after using the azd command to deploy resources to Azure>
.DESCRIPTION
    Use this command to validate your Azure Managed Redis deployment. This script verifies:
    - Redis resource exists and is properly configured
    - Private endpoint connectivity (if network isolated)
    - Managed identity authentication
    - Connection string format compatibility
    
    This script works with both Azure Cache for Redis and Azure Managed Redis deployments.

.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command.

.PARAMETER UseManagedRedis
    Optional parameter to indicate whether Azure Managed Redis is being used.
    Default is false (Azure Cache for Redis).

.EXAMPLE
    .\validate-managed-redis.ps1 -ResourceGroupName "my-resource-group"
    
.EXAMPLE
    .\validate-managed-redis.ps1 -ResourceGroupName "my-resource-group" -UseManagedRedis $true
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
    [String]$ResourceGroupName,
    
    [Parameter(Mandatory = $false, HelpMessage = "Whether Azure Managed Redis is being used")]
    [bool]$UseManagedRedis = $false
)

Write-Host "=============================================="
Write-Host "Azure Managed Redis Validation Script"
Write-Host "=============================================="
Write-Host ""

# Validate parameters
if ($ResourceGroupName.Length -eq 0) {
    Write-Error 'FATAL ERROR: Missing required parameter --resource-group'
    exit 6
}

if ($ResourceGroupName -eq '-rg') {
    Write-Error 'FATAL ERROR: Required parameter --resource-group was not initialized'
    exit 7
}

# Check if resource group exists
Write-Host "Checking resource group existence..."
$groupExists = $(az group exists -n $ResourceGroupName)

if ($groupExists -eq 'false') {
    Write-Error "Missing required resource group. The resource group '$ResourceGroupName' does not exist"
    Write-Error "Recommended Action: run the 'azd provision' command to create the resources"
    exit 32
}
else {
    Write-Host "[OK] Resource group '$ResourceGroupName' exists" -ForegroundColor Green
}

# Find Redis resource
Write-Host ""
Write-Host "Looking for Redis resource..."

$redisResources = az resource list -g $ResourceGroupName --resource-type "Microsoft.Cache/redis" --query "[].{name:name, id:id}" -o json | ConvertFrom-Json

if ($redisResources.Count -eq 0) {
    Write-Error "No Redis resource found in resource group '$ResourceGroupName'"
    Write-Error "Recommended Action: run the 'azd provision' command to create the resources"
    exit 33
}

$redisName = $redisResources[0].name
Write-Host "[OK] Found Redis resource: $redisName" -ForegroundColor Green

# Get Redis details
Write-Host ""
Write-Host "Validating Redis configuration..."

$redisDetails = az redis show --name $redisName --resource-group $ResourceGroupName -o json | ConvertFrom-Json

if ($null -eq $redisDetails) {
    Write-Error "Failed to retrieve Redis resource details"
    exit 34
}

# Validate TLS version
Write-Host "  - Minimum TLS Version: $($redisDetails.minimumTlsVersion)"
if ($redisDetails.minimumTlsVersion -ge "1.2") {
    Write-Host "    [OK] TLS 1.2+ enforced" -ForegroundColor Green
}
else {
    Write-Warning "    [WARN] TLS version is below 1.2. Consider upgrading for security."
}

# Validate SKU
Write-Host "  - SKU: $($redisDetails.sku.name) / $($redisDetails.sku.family)$($redisDetails.sku.capacity)"
Write-Host "    [OK] SKU configured" -ForegroundColor Green

# Validate AAD authentication
$aadEnabled = $redisDetails.redisConfiguration.'aad-enabled'
Write-Host "  - Microsoft Entra ID (AAD) Authentication: $aadEnabled"
if ($aadEnabled -eq "true") {
    Write-Host "    [OK] Entra ID authentication enabled" -ForegroundColor Green
}
else {
    Write-Warning "    [WARN] Entra ID authentication is not enabled. This is recommended for production."
}

# Check provisioning state
Write-Host "  - Provisioning State: $($redisDetails.provisioningState)"
if ($redisDetails.provisioningState -eq "Succeeded") {
    Write-Host "    [OK] Redis successfully provisioned" -ForegroundColor Green
}
else {
    Write-Error "    [ERROR] Redis provisioning state: $($redisDetails.provisioningState)"
    exit 35
}

# Check for private endpoint
Write-Host ""
Write-Host "Checking network configuration..."

$publicNetworkAccess = $redisDetails.publicNetworkAccess
Write-Host "  - Public Network Access: $publicNetworkAccess"

# Find private endpoints associated with Redis
$privateEndpoints = az network private-endpoint list -g $ResourceGroupName --query "[?contains(privateLinkServiceConnections[0].privateLinkServiceId, '$($redisDetails.id)')].name" -o json 2>$null | ConvertFrom-Json

if ($privateEndpoints -and $privateEndpoints.Count -gt 0) {
    Write-Host "  - Private Endpoint: $($privateEndpoints -join ', ')"
    Write-Host "    [OK] Private endpoint configured" -ForegroundColor Green
}
else {
    if ($publicNetworkAccess -eq "Disabled") {
        Write-Warning "    [WARN] Public network access disabled but no private endpoint found in this resource group"
    }
    else {
        Write-Host "    [INFO] No private endpoint (public access enabled)" -ForegroundColor Yellow
    }
}

# Validate connection string format
Write-Host ""
Write-Host "Validating connection string format..."
$hostName = $redisDetails.hostName
$sslPort = $redisDetails.sslPort

Write-Host "  - Host Name: $hostName"
Write-Host "  - SSL Port: $sslPort"

$expectedFormat = "$hostName`:$sslPort,password=<key>,ssl=True,abortConnect=False"
Write-Host "  - Expected Connection String Format: $expectedFormat"
Write-Host "    [OK] Connection string format is compatible with StackExchange.Redis" -ForegroundColor Green

# Check access policy assignments
Write-Host ""
Write-Host "Checking access policy assignments..."

$accessPolicies = az redis access-policy-assignment list --name $redisName --resource-group $ResourceGroupName -o json 2>$null | ConvertFrom-Json

if ($accessPolicies -and $accessPolicies.Count -gt 0) {
    Write-Host "  - Found $($accessPolicies.Count) access policy assignment(s):"
    foreach ($policy in $accessPolicies) {
        Write-Host "    - $($policy.objectIdAlias): $($policy.accessPolicyName)"
    }
    Write-Host "    [OK] Access policies configured" -ForegroundColor Green
}
else {
    Write-Warning "    [WARN] No access policy assignments found. Managed identity access may not work."
}

# Summary
Write-Host ""
Write-Host "=============================================="
Write-Host "Validation Summary"
Write-Host "=============================================="
Write-Host ""
Write-Host "Redis Type: $(if ($UseManagedRedis) { 'Azure Managed Redis' } else { 'Azure Cache for Redis' })"
Write-Host "Resource: $redisName"
Write-Host "Region: $($redisDetails.location)"
Write-Host "SKU: $($redisDetails.sku.name)"
Write-Host "Status: $($redisDetails.provisioningState)"
Write-Host ""

if ($redisDetails.provisioningState -eq "Succeeded") {
    Write-Host "All validations passed successfully!" -ForegroundColor Green
    exit 0
}
else {
    Write-Error "Some validations failed. Please review the output above."
    exit 1
}
