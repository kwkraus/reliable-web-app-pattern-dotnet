
# Feature Specification: Azure Managed Redis Migration

**Feature Branch**: `001-redis-migration`  
**Created**: 2025-12-03  
**Status**: Draft  
**Input**: Migrate from Azure Cache for Redis to Azure Managed Redis with minimal changes to security and SKU configurations

## Clarifications

### Session 2025-12-03

- Q: Deployment strategy for replacing Azure Cache for Redis with Azure Managed Redis? → A: Delete Azure Cache for Redis and deploy Azure Managed Redis in single operation with brief downtime acceptable during deployment
- Q: Target SKU for Azure Managed Redis? → A: Balanced_B1 (1 GB memory, basic tier)
- Q: Rollback mechanism after Azure Cache for Redis deletion? → A: Maintain Bicep template version control with tagged commits; rollback means reverting code and re-running azd provision to redeploy Azure Cache for Redis from infrastructure history
- Q: Specific metrics to monitor for Azure Managed Redis operational readiness? → A: Cache hit ratio, memory usage, connected clients, latency
- Q: Production SKU for Azure Managed Redis? → A: Balanced_B5 (6 GB) to match current Premium P1 capacity exactly

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Infrastructure Developer Replaces Redis Service (Priority: P1)

An infrastructure developer updates the Bicep infrastructure to replace Azure Cache for Redis with Azure Managed Redis in a single deployment operation, accepting brief downtime during the transition. The old Redis resource is deleted and the new Managed Redis is deployed as a direct replacement with environment-specific SKU sizing (Balanced_B1 for dev/test, Balanced_B5 for production).

**Why this priority**: This is the foundation for the entire migration. The infrastructure must be updated to deploy Managed Redis instead of Azure Cache for Redis. This is a prerequisite for all testing and validation.

**Independent Test**: Can be fully tested by updating `infra/core/database/redis/` modules to deploy Managed Redis with environment-based SKU selection, running `azd provision` in a dev environment, and verifying that only Azure Managed Redis Balanced_B1 exists (no Azure Cache for Redis) and the application connects successfully. Delivers immediate value by establishing the new infrastructure.

**Acceptance Scenarios**:

1. **Given** the Bicep templates are updated to use Managed Redis module with environment-based SKU parameter, **When** running `azd provision` in a dev environment, **Then** Azure Managed Redis Balanced_B1 is deployed (no Azure Cache for Redis resource exists)
2. **Given** an existing production environment with Azure Cache for Redis Premium P1, **When** running `azd provision` after infrastructure update, **Then** the old Azure Cache for Redis is deleted and Azure Managed Redis Balanced_B5 is deployed in its place
3. **Given** Azure Managed Redis is deployed in any environment, **When** examining the connection string in Key Vault, **Then** it contains the Managed Redis hostname and port
4. **Given** Managed Redis deployment completes, **When** checking resource group, **Then** no Azure Cache for Redis resources remain and the deployed SKU matches the environment (B1 for dev, B5 for prod)

---

### User Story 2 - Application Maintains Session State with Managed Redis (Priority: P1)

The application (Relecloud web app) must maintain user session state and MSAL token caching functionality with Azure Managed Redis, requiring zero code changes from the existing Azure Cache for Redis implementation.

**Why this priority**: Application compatibility is critical. This validates that the migration is truly transparent to the application layer, requiring no code modifications to the StackExchange.Redis client usage.

**Independent Test**: Can be fully tested by deploying the application with Managed Redis, logging in, adding items to shopping cart, restarting the app, and verifying session persists. Delivers value by confirming application compatibility without code changes.

**Acceptance Scenarios**:

1. **Given** the application is connected to Azure Managed Redis, **When** a user logs in and adds concert tickets to their shopping cart, **Then** the session data is stored in Redis and persists across page refreshes
2. **Given** a user's session is active in Managed Redis, **When** the application is restarted, **Then** the user remains logged in and their cart contents persist
3. **Given** a user authenticates and MSAL token is cached, **When** making subsequent API calls, **Then** authentication works without repeated login prompts (token retrieved from Managed Redis)
4. **Given** the application uses StackExchange.Redis client, **When** checking the package version, **Then** it meets the minimum version 2.6.x requirement with no code modifications needed

---

### User Story 3 - Security Controls Maintained with Managed Redis (Priority: P1)

All security controls (private endpoints, managed identity authentication, RBAC roles, network isolation) must be configured identically to the previous Azure Cache for Redis deployment, ensuring no security regression during the replacement.

**Why this priority**: Security is non-negotiable in production environments. This must be validated before any production migration can occur.

**Independent Test**: Can be fully tested by deploying Managed Redis in dev/test environment, attempting public access (should fail), verifying managed identity authentication works, and confirming private endpoint DNS resolution from App Service. Delivers value by proving security posture is maintained.

**Acceptance Scenarios**:

1. **Given** Azure Managed Redis is deployed in production configuration, **When** attempting to connect from public internet, **Then** connection is denied (private endpoint only)
2. **Given** App Service managed identity has Redis Cache Data Contributor role assigned, **When** the application connects to Managed Redis, **Then** authentication succeeds using managed identity without access keys
3. **Given** Managed Redis has a private endpoint deployed in the spoke VNet subnet, **When** App Service resolves the Redis hostname, **Then** DNS resolves to the private IP address within the VNet
4. **Given** Managed Redis is deployed, **When** examining RBAC role assignments, **Then** the same managed identities have Redis Cache Data Contributor role as they had for the previous Azure Cache for Redis

---

### User Story 4 - Production Deployment with Acceptable Downtime (Priority: P2)

An operations engineer performs a production replacement from Azure Cache for Redis to Azure Managed Redis during a scheduled maintenance window, accepting brief downtime during the transition. Active user sessions will be reset.

**Why this priority**: While critical for production migration, this depends on P1 stories being complete and validated. It's the practical execution of the replacement strategy.

**Independent Test**: Can be fully tested by running `azd provision` in a production-like environment during a test maintenance window, validating deployment completes successfully, confirming application connects to Managed Redis, and verifying monitoring shows no errors. Delivers value by proving the deployment path.

**Acceptance Scenarios**:

1. **Given** production environment is scheduled for maintenance, **When** running `azd provision` with updated Bicep templates, **Then** Azure Cache for Redis is deleted and Azure Managed Redis is deployed within the maintenance window (target: <15 minutes)
2. **Given** Managed Redis deployment completes, **When** App Service instances restart and connect to new Redis, **Then** the application becomes available and users can establish new sessions
3. **Given** Managed Redis is active in production, **When** monitoring Application Insights for 2 hours post-deployment, **Then** no Redis connection errors or authentication failures are logged
4. **Given** issues are detected post-deployment, **When** reverting to the previous git commit/tag and re-running `azd provision`, **Then** Azure Cache for Redis is redeployed and application successfully rolls back within 15 minutes

---

### User Story 5 - Post-Deployment Performance Validation (Priority: P3)

The operations team validates that Azure Managed Redis meets or exceeds the performance SLAs previously established with Azure Cache for Redis, and that costs remain within budget.

**Why this priority**: Important for long-term operational success but not a blocker for migration. Can be evaluated post-deployment.

**Independent Test**: Can be fully tested by establishing baseline performance metrics from Azure Cache for Redis before migration, running load tests against Managed Redis post-deployment, comparing P50/P95/P99 latencies, and reviewing Azure Cost Management reports. Delivers value by informing capacity planning.

**Acceptance Scenarios**:

1. **Given** baseline performance metrics documented from Azure Cache for Redis (P50/P95/P99 latency, throughput), **When** running the same load tests against Managed Redis post-deployment, **Then** latency metrics are equal or better
2. **Given** previous Azure Cache for Redis Premium P1 cost of ~$295/month, **When** reviewing Azure Cost Management after deploying Managed Redis Balanced_B1, **Then** monthly costs are documented and approved within budget
3. **Given** Azure Monitor alerts are configured for Managed Redis, **When** cache hit ratio drops below 80%, memory usage exceeds 90%, connected clients exceed threshold, or latency exceeds P95 baseline, **Then** alerts are triggered and visible in Azure Portal
4. **Given** Managed Redis is deployed in production, **When** querying Application Insights for Redis operation duration, **Then** performance dashboards show cache hit ratio, memory usage, connected clients, and latency metrics meeting or exceeding baseline

---

### Edge Cases

- What happens if the deployment is interrupted during the Redis replacement?
  - Azure deployment is atomic per resource; if Managed Redis deployment fails, the old Azure Cache for Redis deletion may have already occurred. Mitigation: test in non-production first, ensure git tag/commit exists pre-deployment for rollback, have rollback procedure documented and tested
  
- How does the system handle DNS resolution failures when private endpoint is not fully provisioned?
  - Deployment should validate private endpoint connectivity before completing; include health checks in Bicep deployment scripts with retry logic and exponential backoff
  
- What happens if Managed Redis SKU is under-provisioned compared to current Azure Cache for Redis usage?
  - Production uses Balanced_B5 (6 GB) to match Premium P1 capacity exactly; dev/test uses Balanced_B1 (1 GB) which may be smaller than dev Redis if applicable. Pre-deployment validation should compare current memory usage to target SKU capacity and alert if insufficient
  
- How does the system handle the maintenance window exceeding expected duration?
  - Communicate extended maintenance to users; deployment logs should be monitored in real-time; if deployment exceeds 30 minutes, execute rollback procedure (revert git commit, re-run azd provision)
  
- What happens to active user sessions during the Redis replacement?
  - All active sessions will be lost when Azure Cache for Redis is deleted; users will be logged out and must re-authenticate after Managed Redis is available (brief downtime acceptable per clarification)
  
- What happens if rollback is needed but the previous Bicep templates are not found in version control?
  - Pre-deployment checklist MUST verify that current Azure Cache for Redis configuration is committed and tagged in git before proceeding with migration

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Infrastructure MUST replace all Azure Cache for Redis resources with Azure Managed Redis resources
- **FR-002**: Bicep templates MUST deploy Azure Managed Redis with Balanced_B1 SKU (1 GB memory) for development/test environments and Balanced_B5 SKU (6 GB memory) for production to match current Premium P1 capacity
- **FR-003**: Application MUST connect to Azure Managed Redis using existing StackExchange.Redis client (version 2.6.x or higher) without code modifications
- **FR-004**: Connection strings MUST be stored in Azure Key Vault and loaded at application startup
- **FR-005**: Managed Redis MUST use private endpoints for network connectivity (no public access)
- **FR-006**: Authentication MUST use managed identity with RBAC role "Redis Cache Data Contributor" (no access keys)
- **FR-007**: Session state and MSAL token caching MUST function identically to previous Azure Cache for Redis implementation
- **FR-008**: Deployment MUST be atomic per environment (either fully succeeds or fully rolls back)
- **FR-009**: Documentation MUST be updated to reflect Azure Managed Redis configuration and deployment steps
- **FR-010**: Bicep template changes MUST be committed with a tagged release (e.g., v1.0.0-managed-redis) to enable version control-based rollback
- **FR-011**: Rollback procedure MUST be documented with steps to revert git commit and re-run `azd provision` to restore Azure Cache for Redis
- **FR-012**: Azure Monitor alerts MUST be configured for Managed Redis to track cache hit ratio (<80%), memory usage (>90%), connected clients (threshold TBD), and latency (exceeds baseline P95)

### Key Entities

- **Azure Managed Redis Instance**: Replacement caching service with environment-specific SKU (Balanced_B1 for dev/test, Balanced_B5 for production), private endpoint enabled, managed identity authentication, deployed in spoke VNet subnet
- **Connection String**: Redis hostname and port stored in Key Vault secret, retrieved by App Service at startup, format: {hostname}:{port}
- **Private Endpoint**: Network interface providing private IP connectivity from App Service to Managed Redis within VNet
- **RBAC Role Assignment**: "Redis Cache Data Contributor" role granted to App Service managed identity for authentication

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Development environment deploys successfully with Azure Managed Redis Balanced_B1 SKU within 15 minutes; production environment deploys with Balanced_B5 SKU within 15 minutes
- **SC-002**: Application connects to Managed Redis without code changes and maintains session state across restarts (100% compatibility)
- **SC-003**: Post-deployment monitoring shows zero Redis connection errors in Application Insights for 2 hours
- **SC-004**: Managed Redis achieves equal or better performance than previous Azure Cache for Redis (P95 latency ≤ baseline)
- **SC-005**: Security posture maintained with private endpoint (zero public access attempts succeed) and managed identity authentication (zero access key usage)
- **SC-006**: Production deployment completes within scheduled maintenance window (<15 minutes downtime)
- **SC-007**: Documentation updated and validated by at least one team member who successfully deploys using new instructions
- **SC-008**: Azure Monitor dashboards display cache hit ratio, memory usage, connected clients, and latency metrics for Managed Redis within 1 hour of deployment
