# Implementation Plan: Azure Managed Redis Migration

**Branch**: `001-redis-migration` | **Date**: 2025-12-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-redis-migration/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Replace Azure Cache for Redis with Azure Managed Redis across all environments, maintaining identical security posture (private endpoints, managed identity authentication, RBAC) and application compatibility (zero code changes to StackExchange.Redis client). Deploy environment-specific SKUs (Balanced_B1 for dev/test with 1 GB memory, Balanced_B5 for production with 6 GB memory matching current Premium P1 capacity). Accept brief downtime during single-operation replacement, with version control-based rollback capability using tagged Bicep templates.

## Technical Context

**Language/Version**: .NET 8.0 LTS (C# 12), Bicep (Azure IaC)
**Primary Dependencies**: StackExchange.Redis 2.6.x+, Microsoft.Extensions.Caching.StackExchangeRedis, Azure.Identity
**Storage**: Azure Managed Redis (replaces Azure Cache for Redis), Azure Key Vault (connection strings), Azure App Configuration
**Testing**: xUnit (unit tests), Azure CLI/PowerShell (infrastructure validation), Application Insights (monitoring validation)
**Target Platform**: Azure App Service (Linux), Azure Managed Redis, Private Endpoints in hub-and-spoke VNet
**Project Type**: Infrastructure-as-Code migration with existing .NET web application and API
**Performance Goals**: P95 latency ≤ baseline from Azure Cache for Redis, cache hit ratio ≥ 80%, deployment time <15 minutes
**Constraints**: Zero application code changes, maintain security posture (private endpoints only), environment-specific SKU sizing, brief downtime acceptable
**Scale/Scope**: Development (Balanced_B1/1GB), Production multi-region (Balanced_B5/6GB each), session state + MSAL token caching workload

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Validate feature design against the seven core principles from `.specify/memory/constitution.md`:

- [x] **I. Infrastructure as Code**: All Managed Redis resources defined in new Bicep module `infra/core/database/managed-redis.bicep`, replaces `azure-cache-for-redis.bicep`, changes follow IaC review process, reproducible via `azd provision`
- [x] **II. Test-Driven Reliability**: Integration tests planned for connection validation, session persistence across restarts, retry logic verification with StackExchange.Redis client, Application Insights monitoring validation
- [x] **III. Security by Default**: Maintains private endpoint-only access, managed identity authentication with "Redis Cache Data Contributor" RBAC role, no public endpoints, connection strings in Key Vault
- [x] **IV. Observable Operations**: Application Insights integration maintained, Azure Monitor alerts configured for cache hit ratio, memory usage, connected clients, latency metrics
- [x] **V. Consistent User Experience**: Zero code changes to application, maintains session state persistence, MSAL token caching behavior identical, backward compatible (transparent replacement)
- [x] **VI. Performance Accountability**: Performance validation planned with baseline comparison (P50/P95/P99 latency), load testing post-deployment, production SKU sized to match current capacity (6 GB)
- [x] **VII. Configuration Over Convention**: Connection strings externalized in Key Vault, SKU selection parameterized by environment in Bicep templates, no hardcoded Redis configuration

**Exceptions**: None. Migration fully aligns with all seven constitution principles.

## Project Structure

### Documentation (this feature)

```text
specs/001-redis-migration/
├── plan.md              # This file (/speckit.plan command output)
├── spec.md              # Feature specification (completed)
├── research.md          # Phase 0 output (to be created)
├── data-model.md        # Phase 1 output (N/A - infrastructure migration, no data model changes)
├── quickstart.md        # Phase 1 output (deployment and rollback procedures)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
infra/
├── core/
│   └── database/
│       ├── azure-cache-for-redis.bicep  # EXISTING - to be replaced/deprecated
│       └── managed-redis.bicep          # NEW - Azure Managed Redis module
├── modules/
│   ├── application-resources.bicep      # MODIFIED - switch Redis module reference
│   └── naming.bicep                     # REVIEW - may need Managed Redis naming patterns
├── scripts/
│   ├── preprovision/                    # REVIEW - validation scripts
│   └── postprovision/                   # REVIEW - may need Managed Redis validation
└── main.bicep                           # REVIEW - parameter propagation

src/
├── Relecloud.Web.CallCenter/            # NO CHANGES - application code unchanged
│   ├── Program.cs                       # VERIFY - Redis connection configuration
│   └── Startup.cs                       # VERIFY - session state configuration
├── Relecloud.Web.CallCenter.Api/        # NO CHANGES - API code unchanged
└── Relecloud.Web.Models/                # NO CHANGES - models unchanged

tests/
└── integration/                         # NEW - Redis connectivity and session tests
    └── RedisMigrationTests.cs           # NEW - validate Managed Redis compatibility

testscripts/
├── validate-managed-redis.ps1           # NEW - post-deployment validation script
└── README.md                            # MODIFIED - document new validation scripts

docs/ (root level)
├── README.md                            # MODIFIED - update Redis service references
├── prod-deployment.md                   # MODIFIED - update for Managed Redis
└── developer-experience.md              # MODIFIED - update local dev Redis instructions
```

**Structure Decision**: This is an infrastructure-as-code migration project targeting the existing Bicep modules in `infra/core/database/`. The primary change is creating a new `managed-redis.bicep` module and updating the reference in `application-resources.bicep`. Application code in `src/` remains unchanged (zero code modifications required). New validation scripts and integration tests will be added to verify compatibility.

## Complexity Tracking

> **No violations** - Constitution Check passed for all seven principles. This section is not required for this migration.

---

## Phase 0: Research & Discovery

**Objective**: Resolve all NEEDS CLARIFICATION items from Technical Context and research best practices for Azure Managed Redis migration.

### Research Tasks

1. **Azure Managed Redis Bicep Schema**
   - Research: Official Bicep resource schema for `Microsoft.Cache/redisEnterprise` and `Microsoft.Cache/redisEnterprise/databases`
   - Deliverable: Document required properties (SKU names, minimum TLS version, private endpoint configuration, access policies)
   - Source: Azure Bicep documentation, Azure Resource Manager template reference

2. **StackExchange.Redis Compatibility**
   - Research: Verify StackExchange.Redis 2.6.x+ compatibility with Azure Managed Redis connection strings
   - Deliverable: Document any connection string format differences between Azure Cache for Redis and Managed Redis
   - Source: StackExchange.Redis GitHub, Azure Managed Redis documentation

3. **Private Endpoint Configuration**
   - Research: Private endpoint requirements for Azure Managed Redis (subnet delegation, DNS zones, service endpoints)
   - Deliverable: Document DNS private zone name, subnet requirements, network integration differences from Azure Cache for Redis
   - Source: Azure Private Link documentation, Managed Redis networking guide

4. **RBAC Role Assignments**
   - Research: Verify "Redis Cache Data Contributor" role works with Managed Redis, confirm role definition scope
   - Deliverable: Document managed identity authentication configuration and any differences from Azure Cache for Redis
   - Source: Azure RBAC documentation, Managed Redis access control guide

5. **SKU Sizing and Pricing**
   - Research: Balanced_B1 (1GB) and Balanced_B5 (6GB) pricing, features, limitations compared to Premium P1
   - Deliverable: Document cost comparison, feature parity (clustering, persistence, geo-replication support)
   - Source: Azure pricing calculator, Managed Redis SKU comparison documentation

6. **Migration Best Practices**
   - Research: Recommended migration approaches from Azure Cache for Redis to Managed Redis, rollback strategies
   - Deliverable: Document deployment sequence, validation checkpoints, common pitfalls
   - Source: Azure migration guides, community case studies

7. **Monitoring and Diagnostics**
   - Research: Azure Monitor metrics available for Managed Redis (cache hit ratio, memory, latency, connected clients)
   - Deliverable: Document diagnostic settings configuration, alert rule definitions, Application Insights integration
   - Source: Azure Monitor documentation, Managed Redis diagnostics reference

### Output: research.md

Document all findings in `specs/001-redis-migration/research.md` with sections for each research task, including:
- Decision made (e.g., "Use `Microsoft.Cache/redisEnterprise@2024-02-01` API version")
- Rationale (why this choice vs alternatives)
- Alternatives considered (what else was evaluated)
- References (links to official documentation)

**Gate Check**: All NEEDS CLARIFICATION items from Technical Context must be resolved before proceeding to Phase 1.

---

## Phase 1: Design & Contracts

**Prerequisites**: research.md complete, all technical uncertainties resolved

### Design Artifacts

1. **data-model.md** *(Skipped for this migration)*
   - Rationale: This is an infrastructure replacement with no changes to application data models, session state schemas, or database entities. The Redis data structures (session state, MSAL token cache) remain unchanged.

2. **Bicep Module Contract: managed-redis.bicep**
   - Location: `infra/core/database/managed-redis.bicep`
   - Interface:
     - **Inputs**: 
       - `name` (string): Resource name
       - `location` (string): Azure region
       - `tags` (object): Resource tags
       - `skuName` (string): 'Balanced_B1' | 'Balanced_B3' | 'Balanced_B5' | 'Enterprise_E10' etc.
       - `capacity` (int): Number of shards
       - `privateEndpointSettings` (PrivateEndpointSettings): VNet integration config
       - `diagnosticSettings` (DiagnosticSettings): Logging/monitoring config
       - `managedIdentities` (array): Identities to grant access via RBAC
       - `logAnalyticsWorkspaceId` (string): For diagnostics
     - **Outputs**:
       - `id` (string): Resource ID
       - `name` (string): Resource name
       - `hostName` (string): Redis endpoint hostname
       - `sslPort` (int): SSL port (default 10000)
       - `primaryAccessKey` (string?): Access key (not used with managed identity, but available)
   - Alignment: Mirrors interface of existing `azure-cache-for-redis.bicep` for drop-in replacement

3. **Module Integration Contract**
   - Location: `infra/modules/application-resources.bicep`
   - Change: Update module reference from `'../core/database/azure-cache-for-redis.bicep'` to `'../core/database/managed-redis.bicep'`
   - Parameter mapping: Map existing parameters to new module interface (skuName conversion logic if needed)

4. **Connection String Contract**
   - Format: `{hostname}:{port},ssl=true,abortConnect=false`
   - Key Vault secret name: `redisConnectionString` (unchanged)
   - App Configuration key: No changes (connection string sourced from Key Vault)

5. **quickstart.md**
   - **Pre-Deployment Checklist**:
     1. Tag current infrastructure in git: `git tag pre-managed-redis-migration-$(date +%Y%m%d)`
     2. Document current Azure Cache for Redis metrics baseline (memory usage, latency, hit ratio)
     3. Verify StackExchange.Redis package version ≥ 2.6.x in all projects
     4. Schedule maintenance window (15-30 minutes, low-traffic period recommended)
     5. Notify users of planned downtime
   
   - **Deployment Procedure**:
     1. Update Bicep templates on feature branch `001-redis-migration`
     2. Test in development environment: `azd env set AZURE_ENV_NAME dev; azd provision`
     3. Validate application connectivity and session persistence (run integration tests)
     4. Review Application Insights for errors (2-hour monitoring window)
     5. If successful, merge to main and deploy to production: `azd provision`
     6. Monitor production Application Insights for 2 hours post-deployment
   
   - **Rollback Procedure**:
     1. Revert to pre-migration git tag: `git checkout pre-managed-redis-migration-YYYYMMDD`
     2. Re-run deployment: `azd provision` (redeploys Azure Cache for Redis)
     3. Verify application connectivity restored
     4. Document rollback reason and create issue for investigation
   
   - **Validation Steps**:
     1. Check resource group: Verify only Managed Redis exists (no Azure Cache for Redis)
     2. Check SKU: `dev` → Balanced_B1, `prod` → Balanced_B5
     3. Check private endpoint: DNS resolution from App Service → private IP
     4. Check RBAC: App Service managed identity has "Redis Cache Data Contributor" role
     5. Check Key Vault: Connection string secret updated with Managed Redis hostname
     6. Test session: Log in, add to cart, restart app, verify session persists
     7. Check monitoring: Cache hit ratio, memory usage, latency metrics visible in Azure Monitor

### Agent Context Update

After Phase 1 artifacts are created, run:

```pwsh
.\.specify\scripts\powershell\update-agent-context.ps1 -AgentType copilot
```

This updates `.github/copilot-instructions.md` with:
- Azure Managed Redis references
- New Bicep module location
- Updated deployment procedures

**Gate Check**: 
- All design artifacts completed
- quickstart.md validated by manual walkthrough
- Bicep module interfaces documented and reviewed
- Agent context updated

---

## Phase 2: Implementation Planning (Deferred to /speckit.tasks)

**Note**: Phase 2 (task breakdown, file-by-file changes, testing strategy) is handled by the `/speckit.tasks` command and will generate `specs/001-redis-migration/tasks.md`.

The implementation plan stops here. Next steps:

1. **Review this plan** with the team
2. **Execute Phase 0** research to populate `research.md`
3. **Re-run Constitution Check** after research resolves any unknowns
4. **Execute Phase 1** to create quickstart.md and document Bicep contracts
5. **Run `/speckit.tasks`** to generate detailed implementation tasks

---

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Deployment fails mid-operation, Azure Cache for Redis deleted but Managed Redis fails to deploy | **High**: Application down, session loss | Test thoroughly in dev/test environments first; maintain git tag for quick rollback; have runbook ready |
| Managed Redis performance worse than Azure Cache for Redis | **Medium**: User experience degradation | Establish baseline metrics before migration; compare post-deployment; B5 SKU sized to match P1 capacity |
| Private endpoint DNS resolution issues | **Medium**: Application cannot connect to Redis | Pre-validate DNS zone configuration; include health checks in Bicep deployment; test from App Service before cutover |
| StackExchange.Redis client incompatibility | **High**: Application fails to connect | Verify client version 2.6.x+ in research phase; test connection in dev environment before production |
| Cost exceeds budget | **Low**: Unexpected expenses | Document pricing before migration; monitor Azure Cost Management; B1/B5 SKUs chosen for cost parity |
| Rollback takes longer than maintenance window | **Medium**: Extended downtime | Practice rollback procedure in test environment; ensure git tags are ready; have team available during maintenance |

---

## Success Metrics (from spec.md)

- **SC-001**: Development environment deploys successfully with Azure Managed Redis Balanced_B1 SKU within 15 minutes; production environment deploys with Balanced_B5 SKU within 15 minutes
- **SC-002**: Application connects to Managed Redis without code changes and maintains session state across restarts (100% compatibility)
- **SC-003**: Post-deployment monitoring shows zero Redis connection errors in Application Insights for 2 hours
- **SC-004**: Managed Redis achieves equal or better performance than previous Azure Cache for Redis (P95 latency ≤ baseline)
- **SC-005**: Security posture maintained with private endpoint (zero public access attempts succeed) and managed identity authentication (zero access key usage)
- **SC-006**: Production deployment completes within scheduled maintenance window (<15 minutes downtime)
- **SC-007**: Documentation updated and validated by at least one team member who successfully deploys using new instructions
- **SC-008**: Azure Monitor dashboards display cache hit ratio, memory usage, connected clients, and latency metrics for Managed Redis within 1 hour of deployment

---

## Appendix: References

- **Feature Specification**: [spec.md](./spec.md)
- **Constitution**: [.specify/memory/constitution.md](../../.specify/memory/constitution.md)
- **Current Redis Module**: [infra/core/database/azure-cache-for-redis.bicep](../../infra/core/database/azure-cache-for-redis.bicep)
- **Application Resources**: [infra/modules/application-resources.bicep](../../infra/modules/application-resources.bicep)
- **Azure Managed Redis Documentation**: https://learn.microsoft.com/azure/azure-cache-for-redis/managed-redis/
- **Bicep Redis Enterprise Reference**: https://learn.microsoft.com/azure/templates/microsoft.cache/redisenterprise
