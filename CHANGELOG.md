# Changelog

All notable changes to the MAS n8n Azure deployment will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2025-11-06

### Fixed
- **OAuth Redirect URI Issue**: Fixed n8n using `http://0.0.0.0:5678` as OAuth callback URL instead of the public domain
  - Added `N8N_EDITOR_BASE_URL=https://n8n.masadvise.org/` environment variable
  - Added `WEBHOOK_URL=https://n8n.masadvise.org/` environment variable
  - OAuth integrations (Gmail, Google, etc.) now work correctly with proper redirect URIs

- **Database Authentication Failure**: Fixed "password authentication failed for user brian" error
  - Issue: Deployment script generated new random password but PostgreSQL server retained old password
  - Solution: Synchronized PostgreSQL server password with Key Vault secret
  - Container app restarted to establish new database connection

- **Environment Variable Value Loss**: Fixed issue where environment variables lost their values during updates
  - Issue: Scaling operations or partial updates caused variables to be set with names only, no values
  - Solution: Always provide complete list of environment variables with values when updating
  - Added verification commands to documentation

### Changed
- **Deployment Script**: Created `3_deploy_container_app_MAS.sh` specifically for MAS production environment
  - Contains MAS-specific configuration (Canada Central, n8n.masadvise.org, etc.)
  - Includes all required environment variables for OAuth functionality
  - Separate from upstream repository's generic deployment script

- **Environment Variable Management**: Updated all production environment variables
  - Added missing OAuth configuration variables
  - Added TRUST_PROXY and N8N_PROXY_HOPS for proper reverse proxy handling
  - Ensured all n8n feature flags are explicitly set

### Added
- **Comprehensive Documentation**: Created `CLAUDE.md` with complete operational guide
  - Architecture overview with diagrams
  - Detailed resource inventory and configuration
  - Common operations and troubleshooting guides
  - Security best practices and cost optimization tips

- **Environment Variable Management Guide**: Added detailed section in CLAUDE.md
  - Three methods for updating environment variables (single, multiple, deployment script)
  - Warning about common pitfalls when updating variables
  - Verification commands to ensure variables are set correctly

- **Database Password Management Guide**: Added section in CLAUDE.md
  - Explanation of password mismatch issue
  - Step-by-step fix procedure
  - Prevention recommendations

### Technical Details

**Container App Revisions Created:**
- `mas-n8n-app--0000003`: First attempt with OAuth URLs (environment variables lost values during scaling)
- `mas-n8n-app--0000004`: Scaling adjustment (min replicas 0)
- `mas-n8n-app--0000005`: Re-applied environment variables with values
- `mas-n8n-app--pgfix1`: Final revision with database password fix and complete configuration

**Database Changes:**
- Updated PostgreSQL admin password to match Key Vault secret `N8N-DB-Password`
- No schema changes or data loss
- Connection established successfully after password sync

**Key Vault Updates:**
- Secrets regenerated during deployment (N8N-Encryption-Key, N8N-DB-Password, N8N-Admin-Password)
- PostgreSQL server updated to match new database password
- Container app configured with Key Vault secret references (no plaintext passwords)

**Testing Performed:**
- Verified n8n web interface accessible at https://n8n.masadvise.org (HTTP 200)
- Confirmed environment variables set correctly with values
- Validated database connection successful
- Checked OAuth redirect URI now shows `https://n8n.masadvise.org/rest/oauth2-credential/callback`

### Notes for Future Deployments

**Important Lessons Learned:**

1. **Environment Variables**: When using `az containerapp update --set-env-vars`, you MUST include ALL environment variables with their values. Partial updates will cause other variables to lose their values.

2. **Database Passwords**: The deployment script generates new random passwords each time it runs. If PostgreSQL server already exists, it will keep the old password, causing authentication failures. Always sync passwords after running deployment scripts on existing infrastructure.

3. **Container Restarts**: After changing environment variables or database passwords, create a new revision to force containers to pick up the new configuration. Simply updating the configuration doesn't restart running containers.

4. **Verification**: Always verify environment variables after updates using:
   ```bash
   az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
     --query "properties.template.containers[0].env[?name=='VARIABLE_NAME']" --output table
   ```

5. **OAuth Configuration**: For OAuth integrations to work, n8n MUST know its public URL via `N8N_EDITOR_BASE_URL` and `WEBHOOK_URL` environment variables. Without these, it defaults to internal URLs like `0.0.0.0:5678`.

## [1.1.0] - 2025-11-06

### Added
- Initial `CLAUDE.md` documentation with comprehensive deployment guide
- Architecture diagrams and resource inventory
- Common operations and troubleshooting procedures

## [1.0.0] - 2025-08-20

### Added
- Initial deployment to Azure Container Apps
- PostgreSQL Flexible Server database setup
- Azure Key Vault for secrets management
- Azure Container Registry with custom n8n image
- Custom domain configuration: n8n.masadvise.org
- SSL/TLS with Azure-managed certificates
- System-assigned managed identity for secure authentication
- Consumption-based workload profile for cost optimization

### Configuration
- Location: Canada Central (`canadacentral`)
- Resource Group: `mas-n8n-rg`
- Container App: `mas-n8n-app`
- Database: `mas-n8n-postgress-db` (PostgreSQL 14, Standard_B1ms)
- Container Registry: `masbgfn8nacr`
- Key Vault: `mas-n8n-kv`
- Scaling: Min 1, Max 3 replicas
- Resources: 2 vCPU, 4Gi RAM per container

---

**Deployment Owner**: brian.flett@masadvise.org
**Azure Subscription**: 088cc27a-c62c-49a5-908e-57e4610d6af6
**Organization**: MAS Advise Inc.
