# Tasks: Azure Managed Redis Migration

**Input**: Design documents from `/specs/001-redis-migration/`
**Prerequisites**: plan.md ✅, spec.md ✅

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

**Tests**: Integration tests included for User Stories 1-3 (P1) to validate infrastructure replacement and application compatibility.

## Format: `- [ ] [ID] [P?] [Story] Description with file path`

- **Checkbox**: `- [ ]` for pending, `- [x]` for complete
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1, US2, US3, US4, US5)
- File paths included for clarity

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Research and documentation foundation before implementation

- [ ] T001 Research Azure Managed Redis Bicep schema and document in specs/001-redis-migration/research.md (Microsoft.Cache/redisEnterprise resource type, specific API version e.g. 2024-02-01, SKU names, minTLS version 1.2, clustering policy OSSCluster vs EnterpriseCluster, private endpoint requirements)
- [ ] T002 [P] Research StackExchange.Redis 2.6.x+ compatibility with Managed Redis connection strings and document in specs/001-redis-migration/research.md
- [ ] T003 [P] Research private endpoint DNS zone requirements for Managed Redis and document in specs/001-redis-migration/research.md (privatelink.redisenterprise.cache.azure.net)
- [ ] T004 [P] Research RBAC role "Redis Cache Data Contributor" compatibility with Managed Redis and document in specs/001-redis-migration/research.md
- [ ] T005 [P] Research SKU pricing and features for Balanced_B1 (1GB) and Balanced_B5 (6GB) and document in specs/001-redis-migration/research.md
- [ ] T006 [P] Research Azure Monitor metrics available for Managed Redis and document alert configurations in specs/001-redis-migration/research.md (include connected clients threshold: baseline + 20% or >100 clients)
- [ ] T007 Create quickstart.md in specs/001-redis-migration/ with pre-deployment checklist (including AZURE_ENV_NAME environment variable for SKU selection), deployment procedure, rollback procedure, and validation steps
- [ ] T008 Create baseline metrics documentation for current Azure Cache for Redis (P95 latency baseline, memory usage, cache hit ratio) in specs/001-redis-migration/baseline-metrics.md
- [ ] T008b Validate current Redis memory usage against target SKU capacity using Azure Monitor: alert if dev environment >1GB or production >6GB, document findings in specs/001-redis-migration/baseline-metrics.md

**Checkpoint**: Research complete, quickstart.md ready for use

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infrastructure-as-code foundation that MUST be complete before user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T009 Review existing infra/core/database/azure-cache-for-redis.bicep to understand current parameter structure and outputs
- [ ] T010 Review infra/modules/application-resources.bicep line 379 to understand Redis module reference and parameter passing
- [ ] T011 Verify StackExchange.Redis package version ≥ 2.6.x in src/Relecloud.Web.CallCenter/Relecloud.Web.CallCenter.csproj
- [ ] T012 [P] Verify StackExchange.Redis package version ≥ 2.6.x in src/Relecloud.Web.CallCenter.Api/Relecloud.Web.CallCenter.Api.csproj
- [ ] T013 Create xUnit integration test project tests/Integration.Tests/Integration.Tests.csproj with packages: xUnit, xUnit.runner.visualstudio, FluentAssertions, Azure.Identity, StackExchange.Redis, Azure.ResourceManager, Azure.Security.KeyVault.Secrets, Microsoft.Extensions.Configuration

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Infrastructure Developer Replaces Redis Service (Priority: P1) 🎯 MVP

**Goal**: Replace Azure Cache for Redis with Azure Managed Redis in Bicep templates with environment-specific SKU sizing (B1 for dev, B5 for prod)

**Independent Test**: Run `azd provision` in dev environment, verify only Managed Redis B1 exists, confirm application connects successfully

### Integration Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T014 [P] [US1] Create integration test class RedisMigrationTests.cs in tests/Integration.Tests/ with test method ValidateManagedRedisDeployment_DevEnvironment_DeploysBalancedB1Sku
- [ ] T015 [P] [US1] Create integration test method ValidateManagedRedisDeployment_ProdEnvironment_DeploysBalancedB5Sku in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T016 [P] [US1] Create integration test method ValidateConnectionString_StoredInKeyVault_ContainsManagedRedisHostname in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T017 [P] [US1] Create integration test method ValidateResourceGroup_AfterDeployment_NoAzureCacheForRedisExists in tests/Integration.Tests/RedisMigrationTests.cs

### Implementation for User Story 1

- [ ] T018 [US1] Create infra/core/database/managed-redis.bicep with parameters: name, location, tags, skuName, capacity, privateEndpointSettings, diagnosticSettings, managedIdentities, logAnalyticsWorkspaceId
- [ ] T019 [US1] Add outputs to infra/core/database/managed-redis.bicep: id, name, hostName, sslPort, primaryAccessKey
- [ ] T020 [US1] Add Microsoft.Cache/redisEnterprise resource definition in infra/core/database/managed-redis.bicep with SKU configuration
- [ ] T021 [US1] Add Microsoft.Cache/redisEnterprise/databases resource definition in infra/core/database/managed-redis.bicep with clustering policy
- [ ] T022 [US1] Add private endpoint deployment to infra/core/database/managed-redis.bicep using privateEndpointSettings parameter
- [ ] T023 [US1] Add diagnostic settings to infra/core/database/managed-redis.bicep for Azure Monitor integration
- [ ] T023b [US1] Create Azure Monitor alert rules in infra/core/database/managed-redis.bicep for: cache hit ratio <80%, memory usage >90%, connected clients >threshold (from T006), latency exceeds P95 baseline (from T008)
- [ ] T025 [US1] Update infra/modules/application-resources.bicep line 379 to reference '../core/database/managed-redis.bicep' instead of azure-cache-for-redis.bicep (Note: Bicep declarative deployment will implicitly delete Azure Cache for Redis when removed from template)
- [ ] T026 [US1] Add SKU parameter mapping logic in infra/modules/application-resources.bicep to select Balanced_B1 for dev/test, Balanced_B5 for production based on AZURE_ENV_NAME environment variable
- [ ] T026 [US1] Add SKU parameter mapping logic in infra/modules/application-resources.bicep to select Balanced_B1 for dev/test, Balanced_B5 for production based on environment variable
- [ ] T027 [US1] Update Key Vault secret reference in infra/modules/application-resources.bicep to use Managed Redis hostname output
- [ ] T028 [US1] Verify infra/main.bicep parameter propagation supports environment-based SKU selection
- [ ] T029 [US1] Run integration tests T014-T017 to validate deployment (tests should now pass)

**Checkpoint**: User Story 1 complete - Bicep templates deploy Managed Redis with correct SKUs, old Azure Cache for Redis module replaced

---

## Phase 4: User Story 2 - Application Maintains Session State with Managed Redis (Priority: P1)

**Goal**: Validate application connects to Managed Redis with zero code changes, maintaining session state and MSAL token caching

**Independent Test**: Deploy app with Managed Redis, log in, add to cart, restart app, verify session persists

### Integration Tests for User Story 2

- [ ] T030 [P] [US2] Create integration test method ValidateSessionState_UserLogin_PersistsAcrossPageRefresh in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T031 [P] [US2] Create integration test method ValidateSessionState_ShoppingCart_PersistsAfterAppRestart in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T032 [P] [US2] Create integration test method ValidateMSALTokenCache_Authentication_WorksWithoutRepeatedLogin in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T033 [P] [US2] Create integration test method ValidateStackExchangeRedis_PackageVersion_MeetsMinimumRequirement in tests/Integration.Tests/RedisMigrationTests.cs

### Implementation for User Story 2

- [ ] T034 [US2] Review src/Relecloud.Web.CallCenter/Program.cs Redis connection configuration (no changes expected, verify connection string source)
- [ ] T035 [US2] Review src/Relecloud.Web.CallCenter/Startup.cs session state configuration (no changes expected, verify StackExchange.Redis usage)
- [ ] T036 [US2] Review src/Relecloud.Web.CallCenter.Api/Program.cs for MSAL token caching configuration (no changes expected)
- [ ] T037 [US2] Deploy to dev environment with `azd provision` and run integration tests T030-T033 to validate application compatibility (tests should pass)

**Checkpoint**: User Stories 1 AND 2 complete - Application works with Managed Redis, no code changes required

---

## Phase 5: User Story 3 - Security Controls Maintained with Managed Redis (Priority: P1)

**Goal**: Validate all security controls (private endpoints, managed identity, RBAC, network isolation) match previous configuration

**Independent Test**: Deploy Managed Redis, attempt public access (should fail), verify managed identity auth works, confirm private endpoint DNS

### Integration Tests for User Story 3

- [ ] T038 [P] [US3] Create integration test method ValidatePrivateEndpoint_PublicAccess_ConnectionDenied in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T039 [P] [US3] Create integration test method ValidateManagedIdentity_Authentication_SucceedsWithoutAccessKeys in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T040 [P] [US3] Create integration test method ValidatePrivateEndpoint_DNSResolution_ResolvesToPrivateIP in tests/Integration.Tests/RedisMigrationTests.cs
- [ ] T041 [P] [US3] Create integration test method ValidateRBAC_ManagedIdentity_HasRedisCacheDataContributorRole in tests/Integration.Tests/RedisMigrationTests.cs

### Implementation for User Story 3

- [ ] T042 [US3] Verify private endpoint configuration in infra/core/database/managed-redis.bicep includes subnet ID, private DNS zone group, and network policies
- [ ] T044 [US3] Verify Key Vault access policy or RBAC allows App Service to read redisConnectionString secret
- [ ] T045 [US3] Create PowerShell validation script testscripts/validate-managed-redis.ps1 to check: resource existence, SKU correctness, private endpoint DNS, RBAC roles, Key Vault secret (output: Exit 0 on success, Exit 1 on failure, structured output for CI integration)
- [ ] T046 [US3] Run integration tests T038-T041 to validate security controls (tests should pass)ck: resource existence, SKU correctness, private endpoint DNS, RBAC roles, Key Vault secret
- [ ] T046 [US3] Run integration tests T038-T041 to validate security controls (tests should pass)
- [ ] T047 [US3] Run testscripts/validate-managed-redis.ps1 in dev environment to verify all security checks pass

**Checkpoint**: User Stories 1, 2, AND 3 complete - Security posture validated, all P1 stories functional

---

## Phase 6: User Story 4 - Production Deployment with Acceptable Downtime (Priority: P2)

**Goal**: Execute production replacement during maintenance window, accepting brief downtime, with validated rollback capability

**Independent Test**: Run `azd provision` in prod-like environment, validate deployment completes <15 min, app connects, monitoring shows no errors

### Implementation for User Story 4
- [ ] T048 [US4] Tag current infrastructure in git: `git tag pre-managed-redis-migration-$(Get-Date -Format 'yyyyMMdd')` and verify Bicep templates are committed (validate infra/core/database/azure-cache-for-redis.bicep exists in version control)
- [ ] T049 [US4] Document baseline metrics from production Azure Cache for Redis in specs/001-redis-migration/baseline-metrics.md (P95 latency baseline, memory, hit ratio)
- [ ] T049 [US4] Document baseline metrics from production Azure Cache for Redis in specs/001-redis-migration/baseline-metrics.md (latency, memory, hit ratio)
- [ ] T050 [US4] Schedule maintenance window (15-30 minutes, coordinate with stakeholders)
- [ ] T051 [US4] Deploy to production: `azd env set AZURE_ENV_NAME prod; azd provision`
- [ ] T052 [US4] Monitor deployment duration (target: <15 minutes)
- [ ] T053 [US4] Validate App Service restarts and connects to Managed Redis (check Application Insights for connection errors)
- [ ] T054 [US4] Monitor Application Insights for 2 hours post-deployment (verify zero Redis connection errors)
- [ ] T055 [US4] Test rollback procedure in non-production: revert to pre-migration tag, run `azd provision`, verify Azure Cache for Redis restored

**Checkpoint**: Production deployment successful OR rolled back if issues detected

---

## Phase 7: User Story 5 - Post-Deployment Performance Validation (Priority: P3)

**Goal**: Validate Managed Redis meets or exceeds performance SLAs, costs within budget

**Independent Test**: Run load tests, compare P50/P95/P99 latency to baseline, review cost reports

### Implementation for User Story 5

- [ ] T056 [P] [US5] Run load tests against production Azure Managed Redis using same test plan as baseline
- [ ] T057 [P] [US5] Compare P50/P95/P99 latency metrics to P95 latency baseline documented in specs/001-redis-migration/baseline-metrics.md
- [ ] T058 [P] [US5] Review Azure Cost Management for Azure Managed Redis costs (compare to previous ~$295/month for Azure Cache for Redis Premium P1)
- [ ] T059 [P] [US5] Validate Azure Monitor alerts are configured and triggering correctly (cache hit ratio <80%, memory >90%, connected clients exceed threshold, or latency exceeds P95 latency baseline)
- [ ] T060 [P] [US5] Validate Application Insights dashboards display Azure Managed Redis metrics (cache hit ratio, memory usage, connected clients, latency)
- [ ] T061 [US5] Document performance comparison results in specs/001-redis-migration/performance-validation.md

**Checkpoint**: Performance validated, costs approved, monitoring operational

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates and final cleanup

- [ ] T062 [P] Update README.md to reference Azure Managed Redis instead of Azure Cache for Redis (standardize: "Azure Managed Redis" for new service, "Azure Cache for Redis" for legacy)
- [ ] T063 [P] Update prod-deployment.md with Azure Managed Redis deployment steps and SKU sizing guidance (Balanced_B1 (1 GB) for dev, Balanced_B5 (6 GB) for production)
- [ ] T064 [P] Update developer-experience.md with local development Redis instructions (if applicable, use consistent terminology)
- [ ] T065 [P] Update testscripts/README.md to document validate-managed-redis.ps1 usage
- [ ] T066 [P] Add Azure Managed Redis migration notes to workshop/ materials (if applicable)
- [ ] T067 [P] Deprecate or document infra/core/database/azure-cache-for-redis.bicep as legacy (add comment explaining replacement with Azure Managed Redis)
- [ ] T068 Update .github/copilot-instructions.md with Azure Managed Redis references using .\.specify\scripts\powershell\update-agent-context.ps1 -AgentType copilot
- [ ] T069 Create pull request with all changes, request review from team (ensure at least one team member validates deployment using quickstart.md per SC-007)
- [ ] T070 Merge feature branch 001-redis-migration to main after approval

**Final Checkpoint**: All user stories complete, documentation updated, migration production-ready

---

## Dependencies & Parallel Execution

### Story Completion Order

```
Phase 1 (Setup) → Phase 2 (Foundation) 
                    ↓
Phase 3 (US1: Infrastructure) → Phase 4 (US2: Application) → Phase 5 (US3: Security)
                                                                  ↓
                                                    Phase 6 (US4: Production)
                                                                  ↓
                                                    Phase 7 (US5: Performance)
                                                                  ↓
                                                    Phase 8 (Polish)
```

### Parallelizable Tasks by Phase

**Phase 1**: T002, T003, T004, T005, T006 (all research tasks can run concurrently)

**Phase 2**: T012 (verify API project StackExchange.Redis version can run parallel with T011)

**Phase 3**: T014, T015, T016, T017 (all integration tests can be written in parallel before implementation)

**Phase 8**: T062, T063, T064, T065, T066, T067 (all documentation updates can run in parallel)

---

## Implementation Strategy

### MVP Scope (User Story 1 only)

**Minimum viable migration**: Complete Phase 1-3 to deploy Managed Redis in dev environment with validated infrastructure replacement. This proves the Bicep templates work and Managed Redis can be deployed.

**Estimated effort**: ~2-3 days (research + Bicep module creation + integration tests)

### Incremental Delivery

1. **Week 1**: Complete US1 (infrastructure), validate in dev
2. **Week 2**: Complete US2 (application compatibility), US3 (security validation)
3. **Week 3**: Complete US4 (production deployment planning and execution)
4. **Week 4**: Complete US5 (performance validation), Phase 8 (documentation)

### Success Criteria Mapping

- **SC-001** → T051, T052 (deployment timing)
- **SC-002** → T037 (application compatibility)
- **SC-003** → T054 (monitoring validation)
- **SC-004** → T057 (performance comparison)
- **SC-005** → T046 (security validation)
- **SC-006** → T052 (maintenance window)
- **SC-007** → T069 (documentation review)
- **SC-008** → T060 (monitoring dashboards)

---

## Total Task Count: 73 tasks

- **Phase 1 (Setup)**: 9 tasks (added T008b for SKU capacity validation)
- **Phase 2 (Foundation)**: 5 tasks
- **Phase 3 (US1 - Infrastructure)**: 17 tasks (4 tests + 13 implementation, added T023b for alert rules)
- **Phase 4 (US2 - Application)**: 8 tasks (4 tests + 4 implementation)
- **Phase 5 (US3 - Security)**: 10 tasks (4 tests + 6 implementation)
- **Phase 6 (US4 - Production)**: 8 tasks
- **Phase 7 (US5 - Performance)**: 6 tasks
- **Phase 8 (Polish)**: 9 tasks

**Parallel opportunities identified**: 15 tasks marked [P]

**Independent test criteria**: Each user story (US1-US5) has clear acceptance criteria and integration tests

---

## Analysis Report Integration (2025-12-03)

**Changes from `/speckit.analyze` recommendations**:
- Added T008b: SKU capacity validation (HIGH priority)
- Added T023b: Azure Monitor alert rules implementation (MEDIUM priority - FR-012 coverage gap)
- Enhanced T001: Explicit API version, minTLS, clustering policy requirements
- Enhanced T006: Connected clients threshold definition (baseline + 20% or >100)
- Enhanced T007: AZURE_ENV_NAME environment variable documented
- Enhanced T013: Complete package list for integration test project
- Enhanced T025: Clarifying comment about declarative deletion
- Enhanced T045: Output contract specification (exit codes, structured output)
- Enhanced T048: Bicep template verification before tagging
- Standardized terminology: "Azure Managed Redis" (new), "Azure Cache for Redis" (legacy), "P95 latency baseline" (consistent)
- Enhanced T069: Explicit SC-007 validation requirement

**Coverage improvement**: 88.5% → 96.2% (25 of 26 items now have complete coverage)
