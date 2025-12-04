# Testing scripts
These scripts are used by the engineering team to accelerate the testing process through deployment automation.

## Available Scripts

| Script | Description |
|--------|-------------|
| `setup.ps1` | Provisions a new environment with configurable options |
| `cleanup.ps1` | Cleans up a provisioned environment |
| `validate-deployment.ps1` | Validates a deployment is working correctly |
| `validate-managed-redis.ps1` | Validates Azure Managed Redis deployment and configuration |

## Workflow

1. From terminal in the devcontainer start powershell

    ```sh
    pwsh
    ```

1. Install the required PowerShell modules 

    ```pwsh
    Install-Module Az
    ```

    ```pwsh
    Import-Module Az
    ```
    
1. Validate your connection settings

    ```pwsh
    Get-AzContext
    ```

    ```pwsh
    azd config get defaults.subscription
    ```

    * If you are not authenticated then run the following to set your account context.

        ```pwsh
        Connect-AzAccount -UseDeviceAuthentication
        ```
        
        ```pwsh
        azd auth login --use-device-code
        ```

    * If you need to change your default subscription.

        ```pwsh
        Set-AzContext -Subscription {your_subscription_id}
        ```
        
        ```pwsh
        azd config set defaults.subscription {your_subscription_id}
        ```

1. Start a provision

    > It is encouraged to use a distinct name for each deployment
    
    ```pwsh
    .\testscripts\setup.ps1 -NotIsolated -Development -CommonAppServicePlan -SingleLocation -Name reledev7 
    ```

    <!-- .\testscripts\setup.ps1 -Hub -Isolated -Development -NoCommonAppServicePlan -SingleLocation -Name rele231129v1 -->

1. Run a deployment

    ```pwsh
    azd deploy
    ```

1. Clean up a provisioned environment

    > Find the full name of the application resource group to be supplied as the value for *ResourceGroup* param

    ```pwsh
    .\testscripts\cleanup.ps1 -ResourceGroup rg-reledev7-dev-westus3-application
    ```

## Validating Azure Managed Redis

After deployment, you can validate the Azure Managed Redis configuration using:

```pwsh
.\testscripts\validate-managed-redis.ps1 `
    -ResourceGroupName "rg-myapp-dev-westus3-application" `
    -RedisName "redisenterprise-abc123" `
    -ExpectedSku "Balanced_B1"
```

For production environments with network isolation:

```pwsh
.\testscripts\validate-managed-redis.ps1 `
    -ResourceGroupName "rg-myapp-prod-westus3-application" `
    -RedisName "redisenterprise-xyz789" `
    -ExpectedSku "Balanced_B5" `
    -CheckPrivateEndpoint `
    -KeyVaultName "kv-myapp-prod"
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `-ResourceGroupName` | Yes | The Azure resource group containing the Managed Redis instance |
| `-RedisName` | Yes | The name of the Azure Managed Redis instance |
| `-ExpectedSku` | Yes | Expected SKU (e.g., `Balanced_B1` for dev, `Balanced_B5` for production) |
| `-KeyVaultName` | No | Key Vault name to validate connection string secret |
| `-CheckPrivateEndpoint` | No | Switch to validate private endpoint configuration |

### Exit Codes

- `0`: All validation checks passed
- `1`: One or more validation checks failed

The script outputs structured JSON for CI/CD integration.