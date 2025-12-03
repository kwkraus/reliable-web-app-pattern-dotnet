<!--
Sync Impact Report:
- Version Change: Initial → 1.0.0
- Modified Principles: N/A (initial creation)
- Added Sections: All core principles, Technical Standards, Governance
- Removed Sections: None
- Templates Requiring Updates:
  ✅ plan-template.md: Constitution Check section aligns with principles
  ✅ spec-template.md: Requirements sections support principle validation
  ✅ tasks-template.md: Phase organization supports principle-driven development
- Follow-up TODOs: None
-->

# Reliable Web App Pattern (.NET) Constitution

## Core Principles

### I. Infrastructure as Code (NON-NEGOTIABLE)

All Azure infrastructure MUST be defined in Bicep templates with no manual Azure portal changes permitted in production paths. Infrastructure changes MUST follow the same review process as application code. Every resource deployment MUST be reproducible through `azd up` for dev environments and through automated pipelines for production.

**Rationale**: Manual configuration creates drift, makes disaster recovery impossible, prevents consistent multi-region deployments, and blocks the ability to version and audit infrastructure changes. The hub-and-spoke network topology and multi-region architecture demand IaC discipline.

### II. Test-Driven Reliability (NON-NEGOTIABLE)

Production code MUST NOT be deployed without corresponding tests that validate reliability patterns. Integration tests MUST verify retry logic, circuit breakers, and failover behavior. Every Azure service integration MUST have contract tests validating expected behavior under both normal and failure conditions.

**Rationale**: The Reliable Web App pattern promises resilience and availability to users. Without testing failure scenarios (transient faults, regional outages, service throttling), we cannot guarantee the application meets its reliability commitments. Testing is not optional—it is the proof of reliability.

### III. Security by Default

Security configurations MUST default to the most restrictive settings. Network access MUST default to private endpoints with VNet integration. Secrets MUST be stored in Azure Key Vault, never in code or configuration files. Authentication MUST use Microsoft Entra ID with role-based access control. Public endpoints MUST be protected by Azure Front Door with Web Application Firewall enabled.

**Rationale**: Production deployments use network isolation, private endpoints, and defense-in-depth security. Development shortcuts that bypass security create technical debt and training developers in insecure practices. Security must be the default path, not an optional hardening step.

### IV. Observable Operations

Every service MUST emit structured telemetry to Application Insights. Distributed tracing MUST be enabled across all service boundaries (front-end → API → Azure services). Performance metrics MUST be collected and queryable (response times, error rates, dependency durations). Availability monitoring MUST validate user-facing scenarios, not just infrastructure health checks.

**Rationale**: Without observability, we operate blind—unable to diagnose failures, optimize performance, or prove SLA compliance. Application Insights integration is mandatory infrastructure, not a nice-to-have feature. Structured logging enables proactive issue resolution before users are impacted.

### V. Consistent User Experience

UI components MUST follow established patterns from `src/Relecloud.Web.CallCenter/Views` with no unexplained deviations. API contracts MUST maintain backward compatibility or use explicit versioning. Session state MUST persist across scale-out events via Azure Cache for Redis. User journeys MUST be tested end-to-end with acceptance criteria validated before PR approval.

**Rationale**: Relecloud customers expect a consistent, professional ticketing experience. Inconsistent UI patterns confuse users and increase support costs. API breaking changes without versioning break integrations. Session state loss during auto-scaling destroys user trust.

### VI. Performance Accountability

Response time requirements MUST be documented and validated through load testing. Database queries MUST be reviewed for N+1 patterns and missing indexes. API endpoints MUST return responses within documented SLA targets (95th percentile). Static assets MUST be cached and served through Azure Front Door CDN. Performance regressions MUST block PR merging.

**Rationale**: Users abandon slow applications. Azure's scale capabilities are wasted if code is inefficient. The hub-and-spoke topology and multi-region deployment are expensive—we must justify that cost with measurable performance. Load testing catches issues before production impact.

### VII. Configuration Over Convention

Application behavior MUST be configurable through Azure App Configuration, not hardcoded. Environment-specific settings MUST be externalized (connection strings, feature flags, API endpoints). Local development MUST use User Secrets for overrides, never committed secrets. Configuration changes MUST be auditable and versioned.

**Rationale**: The same code artifact deploys to development and production environments with different configurations. Hardcoded values prevent this. Azure App Configuration provides centralized management, versioning, and dynamic refresh without redeployment. Feature flags enable safe rollouts.

## Technical Standards

### Code Quality Requirements

**Language Standards**:
- Target .NET 8.0 LTS minimum
- Enable nullable reference types project-wide
- Use C# 12 language features where they improve clarity
- Follow Microsoft's .NET coding conventions

**Required Code Practices**:
- MUST use dependency injection for all service dependencies
- MUST implement IDisposable/IAsyncDisposable for resource cleanup
- MUST use async/await consistently (no Task.Result or .Wait() blocking calls)
- MUST handle exceptions with try-catch blocks that log structured errors
- MUST validate input parameters with guard clauses
- SHOULD use record types for immutable data transfer objects
- SHOULD use pattern matching for type checking and null checks

**Prohibited Practices**:
- MUST NOT use `#pragma warning disable` without documented justification
- MUST NOT commit commented-out code blocks (use version control)
- MUST NOT use reflection or dynamic typing without explicit justification
- MUST NOT expose internal implementation details through public APIs

### Testing Standards

**Test Coverage Requirements**:
- Unit tests MUST cover all business logic with minimum 80% code coverage
- Integration tests MUST validate all external Azure service dependencies
- Contract tests MUST verify API endpoint schemas and responses
- Load tests MUST validate performance under expected user load

**Test Organization**:
- Unit tests: `tests/unit/` - fast, isolated, no external dependencies
- Integration tests: `tests/integration/` - validates Azure service interactions
- Contract tests: `tests/contract/` - validates API contracts and schemas
- Load tests: Use Azure Load Testing service with JMeter/Locust scripts

**Test Practices**:
- MUST use xUnit as the testing framework for consistency
- MUST use descriptive test names following `MethodName_Scenario_ExpectedBehavior` pattern
- MUST arrange-act-assert (AAA) structure for clarity
- MUST use test fixtures and setup methods to avoid duplication
- MUST mock external dependencies using Moq or NSubstitute
- SHOULD use FluentAssertions for readable assertions

**Resilience Testing** (implements Principle II):
- MUST test retry logic with simulated transient failures
- MUST test circuit breaker tripping and recovery
- MUST test failover scenarios for multi-region deployments
- MUST validate degraded mode behavior when dependencies fail

### Infrastructure as Code Standards

**Bicep Requirements**:
- MUST use modules from `infra/modules/` for reusable resource patterns
- MUST parameterize all environment-specific values
- MUST include resource tags (environment, owner, cost-center)
- MUST use secure parameter decorators for sensitive values
- MUST include diagnostic settings for all resources
- MUST follow naming conventions from `infra/modules/naming.bicep`

**Deployment Automation**:
- MUST use Azure Developer CLI (`azd`) for local deployments
- MUST use CI/CD pipelines (GitHub Actions or Azure DevOps) for production
- MUST run pre-provision validation scripts (`infra/scripts/preprovision/`)
- MUST run post-provision configuration scripts (`infra/scripts/postprovision/`)
- MUST support both development (cost-optimized) and production (resilient) configurations

**Change Management**:
- Infrastructure changes MUST be reviewed like code changes
- Breaking infrastructure changes MUST include migration documentation
- Destructive changes MUST require explicit confirmation
- Resource deletions MUST be soft-deleted where supported (Key Vault, SQL)

### API Design Standards

**RESTful Principles**:
- MUST use HTTP verbs semantically (GET, POST, PUT, PATCH, DELETE)
- MUST return appropriate status codes (200, 201, 400, 401, 404, 500)
- MUST use JSON for request and response bodies
- MUST version APIs explicitly in URL path (`/api/v1/concerts`)
- MUST document endpoints with OpenAPI/Swagger specifications

**Security Requirements**:
- MUST authenticate all API calls using Microsoft Entra ID tokens
- MUST validate token audience and issuer claims
- MUST authorize access using role-based permissions
- MUST sanitize inputs to prevent injection attacks
- MUST rate limit public endpoints using Azure Front Door

**Resilience Requirements**:
- MUST implement retry logic using Polly for downstream dependencies
- MUST implement circuit breaker pattern for failing dependencies
- MUST implement timeout policies on all HTTP calls
- MUST handle partial failures gracefully with degraded responses
- MUST log all failures with correlation IDs for tracing

### Performance Standards

**Response Time Targets**:
- Web pages MUST render initial content within 2 seconds (95th percentile)
- API endpoints MUST respond within 500ms (95th percentile)
- Database queries MUST complete within 100ms (95th percentile)
- Static assets MUST be cached with 1-year cache headers

**Optimization Requirements**:
- MUST minimize database round-trips (eager loading, projections)
- MUST use response caching for read-heavy endpoints
- MUST compress responses with gzip/brotli
- MUST lazy-load non-critical JavaScript and images
- MUST use Azure Cache for Redis for session state and frequently accessed data

**Load Testing Validation**:
- MUST simulate expected production load (concurrent users, requests/second)
- MUST validate auto-scaling triggers and behavior
- MUST measure resource utilization (CPU, memory, database DTUs)
- MUST verify no performance degradation under sustained load

## Development Workflow

### Branch Strategy

- Main branch: `main` - production-ready code, protected
- Feature branches: `###-feature-name` - from issue number
- Branch naming MUST include issue number for traceability
- MUST create PR for all changes (no direct commits to main)

### Pull Request Requirements

**Pre-PR Checklist**:
- [ ] All tests pass locally (`dotnet test`)
- [ ] Code builds without warnings (`dotnet build`)
- [ ] Constitution principles validated (see Constitution Check in plan.md)
- [ ] Changes documented in PR description with issue reference

**PR Review Gates**:
- MUST have minimum 1 approval from code owner
- MUST pass all automated tests in CI pipeline
- MUST pass code quality checks (linting, code coverage)
- MUST include updated tests for modified functionality
- MUST resolve all merge conflicts before approval

**Automated Checks**:
- Build verification (`dotnet build`)
- Unit tests (`dotnet test`)
- Integration tests (if applicable)
- Bicep validation (`az bicep build`)
- Security scanning (Azure DevOps Security Analysis)

### Local Development Practices

**Environment Setup**:
- MUST use Dev Container for consistent development environment
- MUST authenticate to Azure using `azd auth login`
- MUST configure User Secrets for local overrides (never commit secrets)
- SHOULD use WSL for Windows developers for Dev Container performance

**Development Tasks**:
- Build web app: `dotnet build src/Relecloud.Web.CallCenter/Relecloud.Web.CallCenter.csproj`
- Build API: `dotnet build src/Relecloud.Web.CallCenter.Api/Relecloud.Web.CallCenter.Api.csproj`
- Run tests: `dotnet test`
- Deploy to dev: `azd up`
- Watch mode: `dotnet watch run --project src/Relecloud.Web.CallCenter/Relecloud.Web.CallCenter.csproj`

**Connection to Azure Resources**:
- MUST use Azure App Configuration for centralized settings
- MUST use Azure Key Vault for secrets retrieval
- MUST use managed identities for service-to-service authentication
- DEV ONLY: Can use User Secrets for local overrides (see `developer-experience.md`)

## Governance

### Amendment Process

1. Propose changes via GitHub issue with `constitution-amendment` label
2. Document rationale and impact on existing principles
3. Review in team meeting with quorum (50% of core contributors)
4. Approval requires consensus (no blocking objections)
5. Update version according to semantic versioning rules:
   - **MAJOR**: Backward incompatible principle removals or redefinitions
   - **MINOR**: New principle added or materially expanded guidance
   - **PATCH**: Clarifications, wording refinements, typo fixes
6. Update all dependent templates and documentation
7. Create migration plan for existing code (if needed)
8. Communicate changes to all contributors via announcement issue

### Compliance Verification

**Pre-Implementation** (during planning):
- Validate feature design against all seven core principles
- Document any exceptions with explicit justification
- Include Constitution Check in `specs/[###-feature]/plan.md`

**During Implementation**:
- PR reviewers MUST verify principle adherence
- Automated tests MUST validate reliability and performance requirements
- Code quality tools MUST enforce standards

**Post-Deployment**:
- Monitor Application Insights for SLA compliance
- Review telemetry for observability gaps
- Conduct periodic security audits
- Measure actual performance against documented targets

### Exception Handling

Temporary exceptions to principles MUST be documented with:
- Explicit justification linked to business requirements
- Technical debt issue created with remediation plan
- Expiration date or milestone for resolution
- Approval from technical lead and product owner

**Prohibited Exceptions**:
- Security by Default (Principle III) - no exceptions without CISO approval
- Test-Driven Reliability (Principle II) - production code without tests is blocked
- Infrastructure as Code (Principle I) - manual production changes are never permitted

### Version History

**Version**: 1.0.0 | **Ratified**: 2025-12-03 | **Last Amended**: 2025-12-03

**Changelog**:
- **1.0.0** (2025-12-03): Initial constitution ratified
  - Established seven core principles aligned with Reliable Web App pattern
  - Defined technical standards for code quality, testing, IaC, APIs, and performance
  - Documented development workflow and governance processes
  - Integrated with existing copilot-instructions.md for consistency
