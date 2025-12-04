targetScope = 'resourceGroup'

/*
** Azure Managed Redis
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Azure Managed Redis resource (Redis Enterprise), including permission grants and diagnostics.
** This module replaces azure-cache-for-redis.bicep for deployments using Azure Managed Redis.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'
import { PrivateEndpointSettings } from '../../types/PrivateEndpointSettings.bicep'
import { RedisUser } from '../../types/RedisUser.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

@description('The SKU name for Azure Managed Redis. Balanced SKUs are recommended for general workloads.')
@allowed([
  'Balanced_B0'
  'Balanced_B1'
  'Balanced_B3'
  'Balanced_B5'
  'Balanced_B10'
  'Balanced_B20'
  'Balanced_B50'
  'Balanced_B100'
  'Balanced_B150'
  'Balanced_B250'
  'Balanced_B350'
  'Balanced_B500'
  'Balanced_B700'
  'Balanced_B1000'
  'MemoryOptimized_M10'
  'MemoryOptimized_M20'
  'MemoryOptimized_M50'
  'MemoryOptimized_M100'
  'MemoryOptimized_M150'
  'MemoryOptimized_M250'
  'MemoryOptimized_M350'
  'MemoryOptimized_M500'
  'MemoryOptimized_M700'
  'MemoryOptimized_M1000'
  'ComputeOptimized_X3'
  'ComputeOptimized_X5'
  'ComputeOptimized_X10'
  'ComputeOptimized_X20'
  'ComputeOptimized_X50'
  'ComputeOptimized_X100'
  'ComputeOptimized_X150'
  'ComputeOptimized_X250'
  'ComputeOptimized_X350'
  'ComputeOptimized_X500'
  'ComputeOptimized_X700'
  'FlashOptimized_A250'
  'FlashOptimized_A500'
  'FlashOptimized_A700'
  'FlashOptimized_A1000'
  'FlashOptimized_A1500'
  'FlashOptimized_A2000'
  'FlashOptimized_A4500'
])
param skuName string = 'Balanced_B1'

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

param users RedisUser[] = []

// ========================================================================
// VARIABLES
// ========================================================================

// Extract capacity from SKU name (e.g., 'Balanced_B1' -> 1)
// For Azure Managed Redis, the capacity is implicit in the SKU name
var skuCapacity = 1

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource managedRedis 'Microsoft.Cache/redisEnterprise@2024-09-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    minimumTlsVersion: '1.2'
  }
}

resource redisDatabase 'Microsoft.Cache/redisEnterprise/databases@2024-09-01-preview' = {
  name: 'default'
  parent: managedRedis
  properties: {
    clientProtocol: 'Encrypted'
    port: 10000
    clusteringPolicy: 'OSSCluster'
    evictionPolicy: 'VolatileLRU'
    accessKeysAuthentication: 'Enabled'
  }
}

// RBAC role assignments for managed identities
// "Redis Cache Data Contributor" role ID: e0f68234-74aa-48ed-b826-c38b57376e17
var redisCacheDataContributorRoleId = 'e0f68234-74aa-48ed-b826-c38b57376e17'

@batchSize(1)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for user in users: {
  name: guid(managedRedis.id, user.objectId, redisCacheDataContributorRoleId)
  scope: managedRedis
  properties: {
    principalId: user.objectId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', redisCacheDataContributorRoleId)
    principalType: 'ServicePrincipal'
  }
}]

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: managedRedis.id
    linkServiceName: managedRedis.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings - Azure Managed Redis uses different DNS zone and group ID
    dnsZoneName: 'privatelink.redisenterprise.cache.azure.net'
    groupIds: [ 'redisEnterprise' ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: managedRedis
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
      }
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = managedRedis.id
output name string = managedRedis.name
output hostName string = managedRedis.properties.hostName
output sslPort int = 10000
