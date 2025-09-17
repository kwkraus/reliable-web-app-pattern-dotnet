# Redis usage analysis and migration action plan

Date: 2025-09-17

Scope
- Inventory of all places in this repo that provision, configure, or use Azure Cache for Redis.
- High level assessment of migration impact to Azure Managed Redis and an actionable set of next steps.

Key findings (locations)

Code (runtime)
- DI + client helper that configures StackExchange.Redis and AAD token auth:
  - `Relecloud.Web.AzureExtensions.AddAzureStackExchangeRedisCache` — implementation located in `src/Relecloud.Web.CallCenter.Api/AzureExtensions.cs` and used by the web & API startup code.
  - Startup usages: `src/Relecloud.Web.CallCenter/Startup.cs` and `src/Relecloud.Web.CallCenter.Api/Startup.cs` read the configuration key `App:RedisCache:ConnectionString` and call the Redis helper when present.
- NuGet packages used by projects:
  - `src/Relecloud.Web.CallCenter/Relecloud.Web.CallCenter.csproj` — references `Microsoft.Extensions.Caching.StackExchangeRedis` and `Microsoft.Azure.StackExchangeRedis`.
  - `src/Relecloud.Web.CallCenter.Api/Relecloud.Web.CallCenter.Api.csproj` — same package references.

Infrastructure (Bicep)
- `infra/modules/application-resources.bicep` includes a module invocation named `redis` which calls the core module `infra/core/database/azure-cache-for-redis.bicep` to create a `Microsoft.Cache/redis` resource. (See selected line: "Azure Cache for Redis" heading and the `module redis ...` block.)
- Private DNS and Private Endpoint references for Redis use the `privatelink.redis.cache.windows.net` pattern in the infra modules (`infra/modules/private-dns-zones.bicep`, related modules).
- Bicep types related to redis: `infra/types/RedisUser.bicep` and naming helpers in `infra/modules/naming.bicep`.

Configuration & documentation
- Runtime switch: `App:RedisCache:ConnectionString` (used to decide between in-memory vs Redis-backed cache).
- Documentation and workshop/demo references mention and show Azure Cache for Redis (`demo.md`, `workshop/7 - Performance Efficiency/README.md`, assets/images). These will need to be updated.

Behavior / integration notes
- The app uses Redis as the ASP.NET Core distributed cache (via `AddStackExchangeRedisCache`) and for MSAL distributed token caches.
- The code configures AAD token credential integration for Redis using helpers from `Microsoft.Azure.StackExchangeRedis`/StackExchange.Redis (`ConfigureForAzureWithTokenCredentialAsync(...)`).

Migration impact summary (what will need attention)
1. Infrastructure: Bicep modules that deploy `Microsoft.Cache/redis` must be updated if Azure Managed Redis uses a new resource provider, different properties, or different private link DNS. Files to change:
   - `infra/core/database/azure-cache-for-redis.bicep`
   - `infra/modules/application-resources.bicep`
   - `infra/modules/private-dns-zones.bicep`
   - `infra/modules/naming.bicep`
   - `infra/types/RedisUser.bicep`
2. Runtime SDK / codepaths: the DI helper in `src/Relecloud.Web.CallCenter.Api/AzureExtensions.cs` may need to be changed to:
   - remain compatible with the StackExchange.Redis protocol (minimal changes), or
   - switch to a new Azure-provided client library / auth flow if Azure Managed Redis requires it. Update package references in the two project files above accordingly.
3. Configuration & docs: update `App:RedisCache:ConnectionString` expectations and all docs/images referencing the older service.
4. Tests & validation: Add unit/integration tests to verify distributed cache behavior and MSAL token cache with the Managed Redis endpoint and private endpoint configuration.

Actionable next steps (priority)
1. Confirm Azure Managed Redis specifics (resource provider/resource type, stable Bicep schema, private link DNS name, and recommended client SDK & auth pattern). I can fetch and summarize the official docs if you want.
2. Prepare an infra migration PR (draft Bicep changes): replace or augment `infra/core/database/azure-cache-for-redis.bicep` with a Managed Redis resource block, update DNS zone entries, add conditional flag to allow co-existence during cutover.
3. Prepare a runtime PR (code + packages): update `src/Relecloud.Web.CallCenter.Api/AzureExtensions.cs` to support Managed Redis (or maintain StackExchange.Redis compatibility), update csproj packages, and add migration config examples to `appsettings.*` and `demo.md`.
4. End-to-end validation: deploy to a test environment, validate connectivity (public vs private endpoint), AAD auth (TokenCredential flow), cache semantics, and MSAL token cache behavior. Add tests to `tests/` if appropriate.

Risks & testing
- If Azure Managed Redis changes protocol or auth surface, simple client-side upgrades may not work; full client rework could be required.
- Private link DNS differences will break existing private endpoint setups unless Bicep and private DNS zones are updated.
- Suggested test matrix: (a) AAD token auth vs classic key auth, (b) private endpoint enabled vs public access, (c) scaling and failover tests if using clustered/premium SKUs.

Deliverables I can create next (pick one or more)
- Draft infra Bicep PR replacing `Microsoft.Cache/redis` with Managed Redis resource (requires confirmation of resource type/schema).
- Code PR updating `AddAzureStackExchangeRedisCache` and project packages to the Managed Redis recommended client.
- Updated `demo.md` and workshop docs to reference Managed Redis and provide updated connection examples.
- A short test plan and automated integration tests for cache + token cache.

Would you like me to (A) confirm the exact Azure Managed Redis resource type and SDK and then produce the infra + code PRs, or (B) produce a prioritized change list and estimates only? If (A), confirm whether I should look up Azure docs and which environment/subscription (if any) I should assume for resource naming.


---
References (primary files)
- `src/Relecloud.Web.CallCenter.Api/AzureExtensions.cs` (Redis DI & AAD token auth helper)
- `src/Relecloud.Web.CallCenter/Startup.cs` (uses `App:RedisCache:ConnectionString`)
- `src/Relecloud.Web.CallCenter.Api/Startup.cs` (uses `App:RedisCache:ConnectionString`)
- `src/Relecloud.Web.CallCenter/Relecloud.Web.CallCenter.csproj` (StackExchange + Microsoft.Azure.StackExchangeRedis package refs)
- `src/Relecloud.Web.CallCenter.Api/Relecloud.Web.CallCenter.Api.csproj`
- `infra/core/database/azure-cache-for-redis.bicep` (provisions `Microsoft.Cache/redis`)
- `infra/modules/application-resources.bicep` (invokes redis module)
- `infra/modules/private-dns-zones.bicep`
- `infra/types/RedisUser.bicep`
- `demo.md`, `workshop/7 - Performance Efficiency/README.md`

(End of report)
