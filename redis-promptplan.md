# Azure Managed Redis migration — Detailed blueprint and LLM prompt plan

Date: 2025-09-17

Purpose
- Provide a phased, actionable blueprint to migrate this repository from Azure Cache for Redis to Azure Managed Redis.
- Start by provisioning Managed Redis in Bicep in parallel with the existing Cache-for-Redis resources.
- Produce small, safe, iterative implementation chunks; for each chunk provide a self-contained code-generation LLM prompt that includes context, acceptance criteria, and wiring instructions.

How to use
- Execute phases in order. Each phase is broken into small tasks. Each task has a ready-to-send prompt (in a `text` code block) you can give to a code-generation LLM to implement the change.
- After each code-generation pass, run the existing tests and a small manual validation checklist (connectivity, config toggle, private endpoint resolution) before proceeding.

High-level phases
1. Discovery & spec confirmation
2. Infra: Bicep module and DNS support (parallel provisioning)
3. Config + secrets wiring
4. Runtime: DI, compatibility layer, and package updates
5. Validation: E2E deployment and tests
6. Documentation, training, and cutover

PHASE 1 — Discovery & spec confirmation
- Goal: Confirm the exact resource provider, resource type, Bicep schema, private link DNS name, and recommended client SDK + auth pattern for Azure Managed Redis.
- Output: a short spec doc with the resource type (e.g., `Microsoft.???/managedRedis`), required properties, recommended API version, private link DNS name(s), and client SDK packages.

Prompt (Phase 1)
```text
Context: I have a .NET web application that currently uses Azure Cache for Redis (resource type Microsoft.Cache/redis) provisioned via Bicep and the StackExchange.Redis client with AAD TokenCredential integration using Microsoft.Azure.StackExchangeRedis helper.
Task: Research and return an authoritative summary for "Azure Managed Redis" including:
- The exact ARM resource provider and resource type to be used in Bicep (resource type and example resource block).
- The recommended ARM API version for stable production usage.
- Private link / private endpoint DNS names (e.g., pattern like privatelink.<service>.<region>.azure.net) and the required private endpoint group/connection details for Bicep.
- The recommended client SDK(s) for .NET (NuGet package names + versions) and examples for AAD TokenCredential auth or whether only access keys are supported.
- Any major differences in protocol or configuration (e.g., clustering, configuration properties) vs `Microsoft.Cache/redis`.
- One paragraph migration guidance and any gotchas.
Acceptance criteria:
- A bulletized spec that includes sample Bicep resource snippet for Managed Redis and the exact private DNS names to add to infra templates.
- A recommended NuGet package + short code example showing how to construct a client using TokenCredential (if supported) or connection string keys if not.
```

PHASE 2 — Infra: parallel Bicep module for Managed Redis
- Goal: Add a new Bicep module `infra/core/database/managed-redis.bicep` that can be deployed in parallel to `azure-cache-for-redis.bicep`. The module should be configurable via parameters and support optional private endpoint integration.
- Output: the new module + a safe, opt-in hook in `infra/modules/application-resources.bicep` which conditionally deploys Managed Redis when a `deployManagedRedis` parameter is true.

Prompt (Phase 2 — module + app resources)
```text
Context: The repo currently deploys Cache-for-Redis via `infra/core/database/azure-cache-for-redis.bicep` and invokes that module in `infra/modules/application-resources.bicep` using `module redis ...`.
Task:
1) Generate a new Bicep module file `infra/core/database/managed-redis.bicep` that declares the Managed Redis resource with the recommended API version and properties (use the spec from Phase 1). Include parameters:
   - name, location, sku, capacity, diagnosticSettings, users (principal assignments), privateEndpointSettings (structure matching existing modules).
   - output: redisEndpoint, hostName, id, resourceType.
   - When `privateEndpointSettings` is provided, create a private endpoint (or expose the required outputs so a separate private endpoint module can be used).
2) Edit `infra/modules/application-resources.bicep` to add a parallel `module managedRedis` invocation that is guarded by a parameter `deployManagedRedis bool = false`. The managedRedis module should use the same naming and owner identities pattern as the existing `module redis` invocation, and accept the same `users` parameter.
3) Ensure the new module does not replace or delete existing Cache-for-Redis resources by default.
Acceptance criteria:
- `infra/core/database/managed-redis.bicep` exists and compiles (syntactically) as a Bicep module.
- `infra/modules/application-resources.bicep` has a conditional `module managedRedis` invocation controlled by `deployManagedRedis` with clear comments about being opt-in.
- Private endpoint wiring is present but conditioned on provided `privateEndpointSettings` and the module returns a `hostName`/`privateDnsName` output.
```

Phase 2 — small iterative steps
- 2.1 Create `infra/core/database/managed-redis.bicep` skeleton with parameters and outputs.
- 2.2 Add the actual resource block based on Phase 1 spec and wire diagnostic settings.
- 2.3 Update `application-resources.bicep` to add the conditional module invocation and expose a `deployManagedRedis` top-level parameter in its parameter file or calling template.
- 2.4 Add comments and a short README near the new module explaining opt-in, rollback, and coexistence strategy.

PHASE 3 — Private endpoint & private DNS support
- Goal: Ensure Managed Redis private endpoints and DNS zones can be provisioned or linked, matching the existing pattern used for Cache-for-Redis.
- Output: Conditional private endpoint wiring in the Managed Redis module and updates to `infra/modules/private-dns-zones.bicep` to include Managed Redis private DNS names.

Prompt (Phase 3 — private endpoint + DNS)
```text
Context: The project currently adds private endpoint + private DNS entries for Cache-for-Redis using the private DNS zone `privatelink.redis.cache.windows.net` and related modules.
Task:
- Using the Managed Redis private link DNS names from Phase 1, update `infra/modules/private-dns-zones.bicep` and/or the new `managed-redis.bicep` module so the Managed Redis private link names are created/linked when `deployManagedRedis` is true and `privateEndpointSettings` are provided.
- Emit outputs needed for validating DNS resolution (e.g., DNS zone id, recordName).
Acceptance criteria:
- Private DNS and private endpoint wiring works in a dry-run (bicep build/test) and the module returns DNS names to the calling module.
```

PHASE 4 — Config + secrets wiring
- Goal: Add configuration entries and Key Vault/App Configuration wiring to make the Managed Redis connection available to the application at runtime without breaking existing Cache-for-Redis config.
- Pattern: Add `App:RedisCache:Provider` (`CacheForRedis` or `ManagedRedis`) and `App:ManagedRedis:ConnectionString` (or KeyVault reference) while preserving `App:RedisCache:ConnectionString` for backwards compatibility.

Prompt (Phase 4 — config wiring)
```text
Context: The app decides whether to use Redis based on `App:RedisCache:ConnectionString` today. We want to add a provider toggle and KeyVault-backed connection string for Managed Redis while avoiding any downtime.
Task:
- Update any appsettings templates and `demo.md` examples to add `App:RedisCache:Provider` with allowed values `CacheForRedis|ManagedRedis|InMemory` and add `App:ManagedRedis:ConnectionString` as a Key Vault secret name placeholder. Add sample `appsettings.Development.json` provider configuration for local testing.
- If application uses App Configuration or KeyVault templates in infra, add code in Bicep module to store the Managed Redis connection endpoint/secret into Key Vault or App Configuration when created (guarded by deployManagedRedis).
Acceptance criteria:
- `appsettings.*` templates in `src/*/` are updated with the provider and Managed Redis configuration placeholders.
- Bicep returns or writes the secret to Key Vault when requested and the secret name is passed down to `App:ManagedRedis:ConnectionString`.
```

PHASE 5 — Runtime changes (DI & compatibility layer)
- Goal: Update `src/Relecloud.Web.CallCenter.Api/AzureExtensions.cs` so the application can choose between providers at runtime and support both StackExchange.Redis + old AAD helper and the Managed Redis client/SDK. Keep both implementation paths available for cutover testing.

Prompt (Phase 5 — DI + code changes)
```text
Context: Code today uses `services.AddStackExchangeRedisCache(...)` and a helper `AddAzureStackExchangeRedisCache(...)` that integrates AAD TokenCredential via `ConfigureForAzureWithTokenCredentialAsync(...)` from Microsoft.Azure.StackExchangeRedis.
Task:
- Implement a compatibility layer in `src/Relecloud.Web.CallCenter.Api/AzureExtensions.cs` that reads `App:RedisCache:Provider` and:
  - When `CacheForRedis`: use the existing StackExchange.Redis path (no behavior change).
  - When `ManagedRedis`: create the Managed Redis client using the recommended SDK and auth pattern from Phase 1. If the Managed Redis SDK exposes a StackExchange-compatible endpoint and protocol, prefer reusing `AddStackExchangeRedisCache` for cache operations and only use the new SDK for management or secret retrieval if needed.
- Add feature flags and logging to make it obvious at startup which provider was chosen and which connection string (or KeyVault secret) was used.
- Ensure the MSAL distributed token cache wiring uses the same provider abstraction.
Acceptance criteria:
- `AzureExtensions.cs` compiles and behaves correctly for both provider values in local tests.
- Unit tests (or a small harness) can demonstrate switching providers without code changes.
```

Phase 5 — small iterative steps
- 5.1 Add the provider enum/config read and guard code in `AzureExtensions` without changing runtime behavior (default to `CacheForRedis`).
- 5.2 Implement the `ManagedRedis` branch that reads `App:ManagedRedis:ConnectionString` (or KeyVault ref) and constructs a client.
- 5.3 Wire MSAL token cache to use the provider abstraction.
- 5.4 Add logging and feature flagging to ease QA.

PHASE 6 — Testing, E2E deploy & validation
- Goal: Deploy to a dedicated test environment, validate connectivity & behavior for both providers, and run integration tests.

Prompt (Phase 6 — E2E validation)
```text
Context: After adding the Managed Redis module and runtime compatibility, we need to deploy and validate.
Task:
- Provide a deployment checklist and an automated validation script (PowerShell or bash) that:
  - Deploys Bicep with `deployManagedRedis=true` but does not remove existing `redis` module.
  - Confirms Managed Redis resource exists and returns DNS/endpoint outputs.
  - Verifies private DNS resolution from a test VM or a container in the same VNet.
  - Starts the application with `App:RedisCache:Provider=ManagedRedis` and runs a smoke test verifying distributed cache set/get and MSAL token cache storage.
- Create a short test plan with expected outcomes and rollback steps.
Acceptance criteria:
- The smoke test validates read/write to the Managed Redis instance and MSAL token cache storage.
- Private endpoint resolution validated when `isNetworkIsolated=true`.
```

PHASE 7 — Docs, cutover plan & cleanup
- Goal: Update docs, training materials, and perform the production cutover with minimal downtime.

Prompt (Phase 7 — docs & cutover)
```text
Context: After full validation, we will update docs and execute a cutover plan.
Task:
- Draft a cutover runbook that includes:
  - Pre-cutover snapshot checklist (backups, known-good rollbacks, monitoring configured).
  - Step-by-step cutover: flip `App:RedisCache:Provider` to `ManagedRedis` in App Configuration or KeyVault, validate traffic, and monitor telemetry.
  - Post-cutover cleanup: decommission `azure-cache-for-redis` resources after a safe monitoring window.
- Update `demo.md`, workshop materials, and images to reflect Managed Redis (configuration samples + how to find the connection info in Azure).
Acceptance criteria:
- Runbook and docs updated, with a rollback path documented.
```

PHASE 8 — Integration tests and deprecation
- Goal: Add longer-running integration tests and schedule the deprecation of legacy Cache-for-Redis resources.

Prompt (Phase 8 — tests & deprecate)
```text
Context: With Managed Redis in production, we want automated confidence and a controlled deprecation plan.
Task:
- Add integration tests to CI/CD that run against a transient Managed Redis instance when `CI=true` (or use a service-level test harness). Include tests for:
  - Basic set/get for distributed cache
  - MSAL token cache persistence
  - Failover behavior for scaled SKUs
- Draft an automated deprecation checklist script that will remove or tag the old `redis` module resources after a safe operator confirmation.
Acceptance criteria:
- CI pipeline includes integration test steps that can be run manually and on PRs.
- Deprecation checklist and script exist and are documented.
```

Appendix — small iterative task breakdown (micro-steps)
- Phase 1 micro-steps: 1.1 research docs, 1.2 write spec doc, 1.3 confirm SDK examples.
- Phase 2 micro-steps: 2.1 skeleton module, 2.2 resource block + parameter validation, 2.3 conditional module invocation, 2.4 add outputs & README.
- Phase 3 micro-steps: 3.1 confirm private link DNS, 3.2 add private endpoint parameter wiring, 3.3 update `private-dns-zones.bicep`, 3.4 test bicep build.
- Phase 4 micro-steps: 4.1 add provider config keys to appsettings templates, 4.2 add KeyVault secret creation in bicep, 4.3 wire app to read from KeyVault/AppConfig.
- Phase 5 micro-steps: 5.1 add provider detection code, 5.2 implement ManagedRedis client creation, 5.3 unit tests, 5.4 logging & feature flags.
- Phase 6 micro-steps: 6.1 deploy to test subscription, 6.2 automated smoke tests, 6.3 manual validation of private endpoint, 6.4 fix discovered issues.
- Phase 7 micro-steps: 7.1 cutover runbook, 7.2 staged production roll-out, 7.3 post-cutover monitoring.
- Phase 8 micro-steps: 8.1 add CI integration test harness, 8.2 schedule deprecation & resource cleanup.

Small, implementable example of a single micro-step prompt
```text
Context: The repo has an existing Bicep module `infra/core/database/azure-cache-for-redis.bicep`. We need a skeleton for a Managed Redis module file.
Task: Create `infra/core/database/managed-redis.bicep` as a skeleton module that defines the parameters `name`, `location`, `sku`, `capacity`, `diagnosticSettings`, `users`, and `privateEndpointSettings`, and returns outputs `hostName`, `redisEndpoint`, and `id`. Do not include any provider-specific properties beyond placeholders — this is a syntactic skeleton only. Add descriptive comments explaining placeholders and where to insert the actual resource block.
Acceptance criteria: A Bicep file skeleton that compiles (syntax-only) and can be used as the starting point for ensuing iterations.
```

Final notes / best practices
- Keep the Managed Redis module opt-in until the end of cutover; do not remove or replace `azure-cache-for-redis.bicep` until the new service is verified.
- Favor testing with private endpoints enabled in non-production environments to verify DNS and VNet routing early.
- Use feature toggles and provider flags so runtime behavior can be switched with configuration (no code deploy) during cutover.
- Maintain backward compatibility abstractions in code until the legacy Redis resources are safely decommissioned.

---

End of plan.
