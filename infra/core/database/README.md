# Redis Infrastructure Modules

This directory contains Bicep modules for deploying Redis caching solutions in Azure.

## Available Modules

### azure-cache-for-redis.bicep (Legacy)

The original Azure Cache for Redis module. This module creates an Azure Cache for Redis resource with:
- Microsoft Entra ID (AAD) authentication
- Private endpoint support for network isolation
- Diagnostic settings integration
- Access policy assignments for managed identities
- TLS 1.2+ enforcement

**Status:** This module is deprecated but maintained for backward compatibility. New deployments should use `azure-managed-redis.bicep`.

### azure-managed-redis.bicep (Recommended)

The Azure Managed Redis module - the successor to Azure Cache for Redis. This module provides the same interface as the legacy module for seamless migration and includes:
- Microsoft Entra ID (AAD) authentication
- Private endpoint support for network isolation
- Diagnostic settings integration
- Access policy assignments for managed identities
- TLS 1.2+ enforcement
- Updated API version (2024-03-01) with latest features
- Public network access control

## Migration Guide

### Feature Flag Approach

The migration uses a feature flag (`USE_MANAGED_REDIS`) that allows you to switch between the legacy and new Redis implementations without code changes.

### Enable Azure Managed Redis

1. Set the feature flag:
   ```powershell
   azd env set USE_MANAGED_REDIS true
   ```

2. Provision the infrastructure:
   ```powershell
   azd provision
   ```

3. Deploy the application:
   ```powershell
   azd deploy
   ```

### Rollback to Azure Cache for Redis

1. Set the feature flag:
   ```powershell
   azd env set USE_MANAGED_REDIS false
   ```

2. Provision the infrastructure:
   ```powershell
   azd provision
   ```

3. Deploy the application:
   ```powershell
   azd deploy
   ```

### Using the Migration Script

A migration script is provided in `testscripts/migrate-to-managed-redis.ps1`:

```powershell
# Check current status
.\testscripts\migrate-to-managed-redis.ps1 -Action Status

# Enable Azure Managed Redis
.\testscripts\migrate-to-managed-redis.ps1 -Action Enable -Environment dev

# Rollback to Azure Cache for Redis
.\testscripts\migrate-to-managed-redis.ps1 -Action Disable

# Validate the deployment
.\testscripts\migrate-to-managed-redis.ps1 -Action Validate
```

## SKU Mapping

Both modules use the same SKU parameter values:

| SKU | Family | Description |
|-----|--------|-------------|
| Basic | C | Basic tier - suitable for development/testing |
| Standard | C | Standard tier - with replication |
| Premium | P | Premium tier - advanced features, larger capacity |

## Parameters

Both modules accept identical parameters for compatibility:

| Parameter | Type | Description |
|-----------|------|-------------|
| name | string | The name of the Redis resource |
| location | string | Azure region for the resource |
| tags | object | Tags to associate with the resource |
| diagnosticSettings | DiagnosticSettings | Diagnostic logging configuration |
| logAnalyticsWorkspaceId | string | Log Analytics workspace ID for diagnostics |
| enableNonSslPort | bool | Allow non-SSL connections (default: false) |
| redisCacheSku | string | Pricing tier: Basic, Standard, or Premium |
| redisCacheFamily | string | SKU family: C or P |
| redisCacheCapacity | int | Cache capacity (0-6 for C family, 1-4 for P family) |
| privateEndpointSettings | PrivateEndpointSettings? | Private endpoint configuration |
| users | RedisUser[] | Users to grant access policies |

## Outputs

Both modules produce:

| Output | Type | Description |
|--------|------|-------------|
| name | string | The name of the deployed Redis resource |

## Application Compatibility

The connection string format is identical between Azure Cache for Redis and Azure Managed Redis:

```
<hostname>:6380,password=<key>,ssl=True,abortConnect=False
```

No application code changes are required when migrating between the two services. The `StackExchange.Redis` client (version 2.6.x or higher) works with both services.

## Security Considerations

Both modules implement:
- **TLS 1.2+**: Minimum TLS version enforced
- **Microsoft Entra ID Authentication**: Enabled by default
- **Private Endpoints**: Supported for network isolation
- **Access Policies**: Fine-grained access control for managed identities

## Network Configuration

When using private endpoints:
- The private DNS zone `privatelink.redis.cache.windows.net` is used
- Public network access can be disabled
- Private endpoint is created in the specified subnet

## References

- [Azure Cache for Redis Documentation](https://learn.microsoft.com/azure/azure-cache-for-redis/)
- [Azure Managed Redis Documentation](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview)
- [Migration Guide](https://learn.microsoft.com/azure/redis/migrate/migrate-overview)
- [StackExchange.Redis Client](https://github.com/StackExchange/StackExchange.Redis)
