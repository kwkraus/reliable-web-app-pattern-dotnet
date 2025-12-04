# Copilot Instructions for Reliable Web App Pattern (.NET)

## Project Overview
- This repo implements a production-grade, cloud-ready .NET web app for a fictional concert ticketing company (Relecloud), demonstrating the Reliable Web App (RWA) pattern for Azure.
- The architecture uses a hub-and-spoke network, Azure Front Door, App Service, Azure SQL, Azure Managed Redis, Azure Key Vault, App Configuration, and Application Insights.
- The app is designed for both development and production deployments, with infrastructure-as-code (Bicep) in `infra/`.

## Key Structure
- Main app code: `src/Relecloud.Web.CallCenter/` (MVC web app), `src/Relecloud.Web.CallCenter.Api/` (API), `src/Relecloud.Web.Models/` (shared models)
- Infra-as-code: `infra/` (Bicep modules, parameters, scripts)
- Workshop and docs: `workshop/`, `README.md`, `prod-deployment.md`, `developer-experience.md`
- Test/deployment scripts: `testscripts/` (PowerShell, Bash)

## Developer Workflows
- **Dev Container**: Use VS Code Dev Containers for a pre-configured environment. WSL is recommended for Windows.
- **Build**: Use VS Code tasks or `dotnet build` on the relevant `.csproj` files in `src/`.
- **Deploy (dev)**: Use `azd up` after configuring environment with `azd env new <name>`, `azd env set AZURE_SUBSCRIPTION_ID <id>`, and `azd env set AZURE_LOCATION <region>`.
- **Deploy (prod)**: See `prod-deployment.md` for production-specific steps and sizing.
- **Test/validate**: Use scripts in `testscripts/` (e.g., `setup.ps1`, `validate-deployment.ps1`, `validate-managed-redis.ps1`, `cleanup.ps1`).
- **CI/CD**: GitHub Actions in `.github/workflows/` and Azure DevOps pipeline in `.azdo/pipelines/` automate build, deploy, and validation.

## Patterns & Conventions
- **Configuration**: App settings and secrets are loaded from Azure App Configuration and Key Vault at startup.
- **Session State**: Uses Azure Managed Redis for distributed session and token caching.
- **API Auth**: Uses Microsoft Entra ID (Azure AD) and MSAL for secure API calls.
- **Resilience**: Retry and circuit breaker patterns are recommended (see `workshop/4 - Reliability/`). Polly is used for custom retry logic.
- **Networking**: Private endpoints, NSGs, and Azure Firewall restrict access; see Bicep modules in `infra/core/network/`.
- **Monitoring**: Application Insights is integrated for telemetry.

## Project-Specific Guidance
- **Naming**: Environment names must be <18 chars, lowercase, numbers, dashes (e.g., `dotnetwebapp`).
- **Dev/Prod Parity**: Dev deployments are cost-optimized; production uses full hub-and-spoke topology.
- **Redis SKU Sizing**: Development environments use Balanced_B1 (1 GB); production environments use Balanced_B5 (6 GB).
- **Extending CI**: To add validation or teardown, see `scheduled-azure-dev.yml` and `scheduled-azure-teardown.yml` in `.github/workflows/`.
- **First-time setup**: For Azure DevOps, run `create-app-registrations.ps1` to register apps in Entra ID.

## References
- [Main README](../README.md) for architecture and workflow
- [Workshop](../workshop/) for hands-on steps and patterns
- [prod-deployment.md](../prod-deployment.md) for production deployment
- [testscripts/README.md](../testscripts/README.md) for automation scripts
- [Azure Architecture Center article](https://aka.ms/eap/rwa/dotnet/doc)

---
For any unclear or missing conventions, review the above files or ask for clarification.