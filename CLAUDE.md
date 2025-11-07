# n8n Azure Deployment - Claude Code Assistant Guide

## Project Overview

This directory contains the infrastructure-as-code deployment for **n8n workflow automation** on **Azure Container Apps**, deployed for MAS Advise Inc. The deployment was based on the [oriziv5/n8n-azure](https://github.com/oriziv5/n8n-azure) repository and customized for production use.

**Deployment Status**: ✅ **LIVE IN PRODUCTION**
- **Primary URL**: https://n8n.masadvise.org (custom domain with SSL)
- **Azure FQDN**: https://mas-n8n-app.icyflower-6df495da.canadacentral.azurecontainerapps.io
- **Location**: Canada Central region
- **Created**: August 20, 2025 by brian.flett@masadvise.org

---

## Azure Resources Deployed

### Resource Group: `mas-n8n-rg`
**Location**: Canada Central (`canadacentral`)

| Resource Name | Resource Type | Purpose | Status |
|--------------|---------------|---------|--------|
| `mas-n8n-app` | Container App | Main n8n application | Running |
| `mas-n8n-postgress-db` | PostgreSQL Flexible Server | Persistent database storage | Ready |
| `mas-n8n-kv` | Key Vault | Secrets management (RBAC enabled) | Active |
| `masbgfn8nacr` | Container Registry | Custom n8n Docker images | Active |
| `mas-n8n-workload-profile` | Managed Environment | Container Apps runtime environment | Succeeded |
| `workspace-masn8nrgK7Sq` | Log Analytics Workspace | Monitoring and logging | Active |

---

## Architecture Details

### Container App: `mas-n8n-app`

**Container Configuration**:
- **Image**: `masbgfn8nacr.azurecr.io/mas-n8n-image:latest`
- **Base**: Azure Linux 3 (optimized for Azure workloads)
- **Node.js Version**: 22.12.0
- **n8n Version**: Latest
- **Resources**: 2 vCPU, 4Gi RAM, 8Gi ephemeral storage
- **Scaling**: Min 1 replica, Max 3 replicas
- **Port**: 5678 (exposed externally)
- **Workload Profile**: Consumption (pay-per-use)

**Security Features**:
- System-assigned managed identity: `9db7c19d-e186-40b2-a47b-12596375a1d4`
- Non-root container execution
- Key Vault secret references (no secrets in environment variables)
- Basic authentication enabled (username: `brian`)
- SSL/TLS with custom domain certificate

**Authentication Method**:
- ACR access: Managed identity with `AcrPull` role
- Key Vault access: Managed identity with `Key Vault Secrets User` role
- PostgreSQL access: Password-based (secret from Key Vault)

**Custom Domain**:
- Domain: `n8n.masadvise.org`
- Managed certificate: Auto-provisioned Azure managed certificate
- Binding: SNI Enabled
- Certificate ID: `/subscriptions/.../managedCertificates/n8n.masadvise.org-mas-n8n--250820192615`

### PostgreSQL Flexible Server: `mas-n8n-postgress-db`

**Configuration**:
- **SKU**: Standard_B1ms (Burstable tier) - Cost-optimized
- **Storage**: 32 GB (120 IOPS, P4 tier)
- **PostgreSQL Version**: 14.19
- **Admin User**: `brian`
- **Database Name**: `n8n`
- **FQDN**: `mas-n8n-postgress-db.postgres.database.azure.com`
- **High Availability**: Disabled (cost optimization)
- **Geo-Redundant Backup**: Disabled
- **Backup Retention**: 15 days (updated from initial 7 days)
- **Availability Zone**: 2

**Network Configuration**:
- **Public Access**: Enabled (0.0.0.0 - firewall rules required)
- **SSL**: Enabled but not enforced (DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false)
- **Connection Timeout**: 3000ms

### Key Vault: `mas-n8n-kv`

**Configuration**:
- **URI**: https://mas-n8n-kv.vault.azure.net/
- **SKU**: Standard
- **Authorization**: RBAC (not access policies)
- **Soft Delete**: Enabled (90-day retention)
- **Purge Protection**: Not enabled

**Secrets Stored**:
1. `N8N-Encryption-Key` - n8n data encryption key (auto-generated)
2. `N8N-DB-Password` - PostgreSQL database password (auto-generated)
3. `N8N-Admin-Password` - n8n admin user password (auto-generated)

**Access Control**:
- Container App managed identity: `Key Vault Secrets User` role
- Deployment user (brian.flett@masadvise.org): `Key Vault Secrets Officer` role

### Container Registry: `masbgfn8nacr`

**Configuration**:
- **Login Server**: `masbgfn8nacr.azurecr.io`
- **SKU**: Basic tier
- **Admin User**: Enabled (fallback authentication)
- **Image**: `mas-n8n-image:latest`

**Security**:
- Azure AD authentication enabled
- Managed identity authentication configured
- Public network access enabled

### Container App Environment: `mas-n8n-workload-profile`

**Configuration**:
- **Default Domain**: `icyflower-6df495da.canadacentral.azurecontainerapps.io`
- **Static IP**: `4.248.208.42`
- **Workload Profile**: Consumption (serverless)
- **Logging**: Log Analytics workspace integration
- **Dapr Version**: 1.13.6-msft.6
- **KEDA Version**: 2.17.2

**Outbound IP Addresses** (for firewall whitelisting):
```
20.175.131.120, 20.175.131.81, 130.107.205.172, 4.248.202.254, 40.82.191.244,
130.107.46.96, 130.107.173.153, 20.175.131.103, 20.175.131.130, 20.116.137.89,
20.116.137.87, 20.116.137.109, 20.116.137.103, 20.116.137.113, 20.116.137.115,
20.200.119.152, 20.200.119.174, 20.200.119.159, 20.200.119.172, 4.172.39.65,
4.172.39.74, 4.172.39.70, 4.172.39.51, 4.172.39.53, 4.172.39.43, 4.172.20.129
```

---

## Deployment Scripts

### 1. `1_create_workload_profile.sh`
Creates the foundational Azure infrastructure.

**What it does**:
- Creates resource group `mas-n8n-rg` in Canada Central
- Creates Container App environment `mas-n8n-workload-profile`
- Configures Consumption workload profile (0-10 nodes)

**Configuration Variables**:
```bash
RESOURCE_GROUP="mas-n8n-rg"
LOCATION="canadacentral"
WORKLOAD_PROFILE_NAME="mas-n8n-workload-profile"
```

**When to run**: Only needed once during initial setup. Already completed.

### 2. `2_build_image.sh`
Builds and pushes the custom n8n Docker image to Azure Container Registry.

**What it does**:
- Creates Azure Container Registry `masbgfn8nacr` (if not exists)
- Builds Docker image using `Dockerfile.azurelinux`
- Pushes image as `mas-n8n-image:latest` to ACR
- Verifies image was pushed successfully

**Configuration Variables**:
```bash
ACR_NAME="masbgfn8nacr"
IMAGE_NAME="mas-n8n-image"
RESOURCE_GROUP="mas-n8n-rg"
LOCATION="canadacentral"
DOCKERFILE_PATH="Dockerfile.azurelinux"
```

**When to run**:
- Initial deployment (completed)
- When updating the Docker image (n8n version upgrades, custom configurations)

**Image Build Details**:
- Uses Azure's cloud build service (faster, platform-agnostic)
- Multi-architecture support (x64/ARM64)
- Security: Non-root user, minimal attack surface

### 3. `3_deploy_container_app.sh`
Deploys or updates the n8n Container App with all configurations.

**What it does**:
1. **Validates prerequisites**: Checks for environment, ACR, and image
2. **PostgreSQL setup**: Creates database server and database (if not exists)
3. **Key Vault setup**: Creates vault and stores secrets (if not exists)
4. **RBAC configuration**: Assigns roles for managed identity access
5. **Container App deployment**: Creates or updates the app with full configuration
6. **Environment variables**: Configures n8n with all required settings

**Configuration Variables**:
```bash
# Application
CONTAINER_APP_NAME="mas-n8n-app"
LOCATION="canadacentral"
RESOURCE_GROUP="mas-n8n-rg"

# Database
DB_SERVER_NAME="mas-n8n-postgress-db"
DB_ADMIN_USER="brian"
DB_NAME="n8n"

# n8n Configuration
N8N_DOMAIN="n8n.masadvise.org"
N8N_USERNAME="brian"

# Azure Resources
ACR_NAME="masbgfn8nacr"
IMAGE_NAME="mas-n8n-image"
KEYVAULT_NAME="mas-n8n-kv"
```

**When to run**:
- Initial deployment (completed)
- Configuration updates (environment variables)
- After rebuilding Docker image (updates image reference)
- Scaling adjustments
- Troubleshooting and fixes

**Smart Features**:
- **Idempotent**: Safe to run multiple times, skips existing resources
- **RBAC retry logic**: Handles Azure RBAC propagation delays (up to 3 minutes)
- **Fallback authentication**: Uses admin credentials if managed identity fails
- **Detailed logging**: Timestamped logs with troubleshooting guidance

---

## Environment Variables

The Container App is configured with these environment variables:

### n8n Core Configuration
```bash
N8N_ENCRYPTION_KEY=secretref:n8n-encryption-key  # From Key Vault
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=brian
N8N_BASIC_AUTH_PASSWORD=secretref:n8n-admin-password  # From Key Vault
GENERIC_TIMEZONE=Asia/Jerusalem
N8N_LOG_LEVEL=error
N8N_LOG_OUTPUT=console
```

### Database Configuration
```bash
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=mas-n8n-postgress-db.postgres.database.azure.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=brian
DB_POSTGRESDB_PASSWORD=secretref:n8n-db-password  # From Key Vault
DB_POSTGRESDB_CONNECTION_TIMEOUT=3000
DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false
```

### Proxy and Network
```bash
TRUST_PROXY=true
N8N_PROXY_HOPS=1
```

### Feature Flags
```bash
N8N_RUNNERS_ENABLED=true
N8N_DIAGNOSTICS_ENABLED=false
N8N_VERSION_CHECK_ENABLED=false
N8N_TEMPLATES_ENABLED=false
N8N_DISABLE_EXTERNAL_ERROR_REPORTING=false
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
```

**Note**: Domain-specific variables (`N8N_EDITOR_BASE_URL`, `WEBHOOK_URL`) are commented out as Azure Container Apps handles URL routing automatically.

---

## How I Created This Deployment

### Initial Setup (August 20, 2025)

1. **Cloned Repository**:
   ```bash
   git clone https://github.com/oriziv5/n8n-azure.git
   cd n8n-azure
   ```

2. **Customized Configuration**:
   - Updated all scripts with MAS-specific naming (`mas-n8n-*`)
   - Changed location to Canada Central (closer to primary users)
   - Configured custom domain `n8n.masadvise.org`
   - Set timezone to Asia/Jerusalem
   - Optimized database to Burstable tier for cost savings

3. **Ran Deployment Scripts**:
   ```bash
   # Step 1: Create infrastructure
   ./1_create_workload_profile.sh

   # Step 2: Build and push Docker image
   ./2_build_image.sh

   # Step 3: Deploy container app
   ./3_deploy_container_app.sh
   ```

4. **Post-Deployment**:
   - Configured DNS CNAME: `n8n.masadvise.org` → `mas-n8n-app.icyflower-6df495da.canadacentral.azurecontainerapps.io`
   - Azure automatically provisioned managed SSL certificate
   - Verified n8n accessible at https://n8n.masadvise.org

### Key Decisions Made

**Database**:
- Chose PostgreSQL 14 (stable, well-supported by n8n)
- Selected Burstable tier (Standard_B1ms) for cost optimization
- Disabled high availability (not critical for workflow automation)
- Set 15-day backup retention (adequate for recovery)

**Container App**:
- Consumption workload profile (pay only for usage)
- Min 1 replica (always-on availability)
- Max 3 replicas (handles traffic spikes)
- 2 vCPU / 4Gi RAM (sufficient for n8n workflows)

**Security**:
- Managed identity for all Azure resource authentication
- RBAC-based Key Vault (modern, auditable)
- Auto-generated strong secrets (32-byte base64)
- Basic auth for n8n (username/password protection)
- SSL/TLS with Azure-managed certificates

**Docker Image**:
- Azure Linux 3 base (lightweight, optimized for Azure)
- Node.js 22.12.0 (meets n8n requirements: >=20.19 <= 24.x)
- Non-root user execution (security best practice)
- Latest n8n version (auto-updated)

---

## How to Get Claude's Help

### Common Operations

#### 1. **Viewing Logs**
Ask Claude:
> "Show me the n8n container app logs"

Claude will run:
```bash
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow
```

#### 2. **Updating n8n Version**
Ask Claude:
> "Update n8n to the latest version"

Claude will:
1. Run `./2_build_image.sh` to rebuild image with latest n8n
2. Run `./3_deploy_container_app.sh` to deploy updated image
3. Verify deployment succeeded
4. Check logs for any issues

#### 3. **Scaling Configuration**
Ask Claude:
> "Increase max replicas to 5"

Claude will:
```bash
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --max-replicas 5
```

#### 4. **Environment Variable Updates**

**IMPORTANT**: Updating environment variables requires careful attention to ensure all values are preserved.

**Method 1: Update Single Environment Variable (Safe)**

Ask Claude:
> "Change the timezone to America/Toronto"

Claude will run:
```bash
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --set-env-vars "GENERIC_TIMEZONE=America/Toronto"
```

**Method 2: Update Multiple Environment Variables (Use with Caution)**

When updating multiple variables, you MUST include ALL environment variables with their values, not just the ones you're changing. Otherwise, variables will lose their values.

Ask Claude:
> "Update environment variables for OAuth support"

Claude will run the full set of environment variables:
```bash
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --set-env-vars \
    "N8N_ENCRYPTION_KEY=secretref:n8n-encryption-key" \
    "DB_TYPE=postgresdb" \
    "DB_POSTGRESDB_HOST=mas-n8n-postgress-db.postgres.database.azure.com" \
    "DB_POSTGRESDB_PORT=5432" \
    "DB_POSTGRESDB_DATABASE=n8n" \
    "DB_POSTGRESDB_USER=brian" \
    "DB_POSTGRESDB_PASSWORD=secretref:n8n-db-password" \
    "GENERIC_TIMEZONE=Asia/Jerusalem" \
    "N8N_BASIC_AUTH_ACTIVE=true" \
    "N8N_BASIC_AUTH_USER=brian" \
    "N8N_BASIC_AUTH_PASSWORD=secretref:n8n-admin-password" \
    "TRUST_PROXY=true" \
    "N8N_PROXY_HOPS=1" \
    "N8N_EDITOR_BASE_URL=https://n8n.masadvise.org/" \
    "WEBHOOK_URL=https://n8n.masadvise.org/" \
    --output none
```

**Method 3: Use MAS Deployment Script (Recommended for Major Changes)**

For comprehensive updates or when you're unsure, use the deployment script:
```bash
./3_deploy_container_app_MAS.sh
```

**Common Pitfall**: If you only provide some variables, the others will be set without values (just the name). Always verify after updating:

```bash
# Check specific environment variables
az containerapp show \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --query "properties.template.containers[0].env[?name=='N8N_EDITOR_BASE_URL' || name=='WEBHOOK_URL']" \
  --output table
```

#### 5. **Database Password Management**

**CRITICAL**: The PostgreSQL password must match the password stored in Key Vault.

**Common Issue**: If you run the deployment script (`3_deploy_container_app_MAS.sh`), it generates a NEW random password and updates Key Vault, but PostgreSQL keeps the OLD password. This causes authentication failures.

**How to Fix Password Mismatch:**

Ask Claude:
> "n8n shows 'password authentication failed for user brian'"

Claude will:
1. Retrieve the current password from Key Vault
2. Update PostgreSQL server to match:

```bash
# Get password from Key Vault
DB_PASSWORD=$(az keyvault secret show \
  --vault-name mas-n8n-kv \
  --name N8N-DB-Password \
  --query "value" \
  --output tsv)

# Update PostgreSQL server
az postgres flexible-server update \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db \
  --admin-password "$DB_PASSWORD"

# Force container restart to reconnect
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --revision-suffix "dbfix$(date +%s)"
```

**Prevention**: When running deployment scripts, be aware they generate new secrets. Existing PostgreSQL servers need password updates.

#### 6. **Database Connection Issues**
Ask Claude:
> "n8n can't connect to the database, help troubleshoot"

Claude will:
1. Check PostgreSQL server status
2. Verify firewall rules allow Container App IPs
3. Test database connectivity
4. Check Key Vault secret retrieval
5. Review container logs for connection errors
6. Check for password mismatches (see section 5 above)

#### 7. **Checking Costs**
Ask Claude:
> "Show me the current Azure costs for n8n"

Claude will:
```bash
az consumption usage list --start-date $(date -d "30 days ago" +%Y-%m-%d) --end-date $(date +%Y-%m-%d) | grep mas-n8n
```

#### 8. **Backup and Restore**
Ask Claude:
> "Create a backup of the n8n database"

Claude will:
```bash
az postgres flexible-server backup create \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db \
  --backup-name "manual-backup-$(date +%Y%m%d)"
```

#### 9. **Custom Domain Issues**
Ask Claude:
> "The custom domain n8n.masadvise.org isn't working"

Claude will:
1. Check DNS CNAME record
2. Verify managed certificate status
3. Check custom domain binding
4. Test SSL/TLS certificate
5. Review ingress configuration

#### 10. **Security Audit**
Ask Claude:
> "Audit the security configuration of the n8n deployment"

Claude will review:
- Managed identity permissions (least privilege)
- Key Vault access policies
- Network security (public access, firewall rules)
- SSL/TLS configuration
- Container security (non-root user)
- Secret management (no plaintext secrets)

#### 11. **Performance Issues**
Ask Claude:
> "n8n is running slow, help optimize performance"

Claude will:
1. Check current resource usage (CPU, memory)
2. Review replica count and scaling rules
3. Analyze database performance metrics
4. Check container logs for errors
5. Suggest scaling adjustments if needed

### Troubleshooting Common Issues

#### Issue: Container App Won't Start
Ask Claude:
> "The container app shows 'Provisioning' status and won't start"

Claude will check:
- Image pull authentication (managed identity AcrPull role)
- Key Vault secret access (managed identity permissions)
- Container logs for startup errors
- Database connectivity

#### Issue: Can't Access n8n Web Interface
Ask Claude:
> "I can't access n8n at n8n.masadvise.org"

Claude will verify:
- Container App running status
- Ingress configuration (external, port 5678)
- Custom domain binding
- SSL certificate status
- DNS resolution

#### Issue: Workflows Not Saving
Ask Claude:
> "Workflows aren't being saved in n8n"

Claude will check:
- Database connection status
- PostgreSQL server health
- Database user permissions
- Container logs for database errors
- Key Vault secret retrieval

### Maintenance Tasks

#### Monthly Security Updates
Ask Claude:
> "Perform monthly security updates for n8n"

Claude will:
1. Rebuild Docker image with latest base image and n8n version
2. Review and apply any security patches
3. Update environment variables if needed
4. Deploy updated image
5. Verify deployment health
6. Check logs for issues

#### Cost Optimization Review
Ask Claude:
> "Review and optimize Azure costs for n8n"

Claude will:
1. Analyze current resource usage
2. Check database tier appropriateness
3. Review scaling configuration
4. Suggest potential optimizations (e.g., reduce max replicas if unused)
5. Review backup retention policies

#### Disaster Recovery Test
Ask Claude:
> "Test the disaster recovery process for n8n"

Claude will:
1. Create a point-in-time database backup
2. Document restoration steps
3. Verify backup integrity
4. Test Key Vault secret recovery
5. Document RTO (Recovery Time Objective) and RPO (Recovery Point Objective)

---

## Important File Locations

### Local Development
- **Current Directory**: `/home/brian/workspace/docker/development/n8n-azure/`
- **Deployment Scripts**: `./1_create_workload_profile.sh`, `./2_build_image.sh`, `./3_deploy_container_app.sh`
- **Dockerfiles**: `./Dockerfile.azurelinux`, `./Dockerfile` (simple version)
- **Documentation**: `./README.md`, `./CLAUDE.md` (this file)

### Azure Resources
- **Resource Group**: `mas-n8n-rg` (Canada Central)
- **Container App**: `mas-n8n-app`
- **PostgreSQL**: `mas-n8n-postgress-db.postgres.database.azure.com`
- **Key Vault**: `https://mas-n8n-kv.vault.azure.net/`
- **Container Registry**: `masbgfn8nacr.azurecr.io`

### Monitoring and Logs
- **Azure Portal**: https://portal.azure.com/#browse/resourcegroups → `mas-n8n-rg`
- **Container Logs**: `az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow`
- **Log Analytics Workspace**: `workspace-masn8nrgK7Sq`

---

## Cost Breakdown (Estimated Monthly)

Based on current configuration:

| Resource | SKU/Tier | Estimated Cost |
|----------|----------|---------------|
| Container App (Consumption) | 2 vCPU, 4Gi RAM, 1-3 replicas | $30-60 |
| PostgreSQL Flexible Server | Standard_B1ms, 32GB | $25-30 |
| Container Registry | Basic tier | $5 |
| Key Vault | Standard, ~3 secrets | $1 |
| Log Analytics | Pay-as-you-go | $5-10 |
| **Total** | | **~$66-106/month** |

**Cost Optimization Opportunities**:
- Reduce min replicas to 0 (scale to zero when idle) - saves ~$15-30/month
- Reduce max replicas if traffic is low
- Consider Reserved Instances for PostgreSQL (40% discount with 1-year commitment)

---

## Security Best Practices

✅ **Currently Implemented**:
- System-assigned managed identity (no credentials in code)
- RBAC-based Key Vault access (auditable, granular)
- Auto-generated strong secrets (32-byte base64)
- SSL/TLS with Azure-managed certificates
- Non-root container execution
- Basic authentication for n8n access
- Soft delete enabled on Key Vault (90-day recovery)
- Azure Linux 3 base (minimal attack surface)

⚠️ **Recommendations for Enhanced Security**:
- Enable PostgreSQL firewall rules (restrict to Container App IPs only)
- Enable Key Vault purge protection (prevent accidental deletion)
- Configure Azure AD authentication for n8n (instead of basic auth)
- Enable VNet integration (private networking)
- Add Azure Front Door with WAF (DDoS protection, geo-filtering)
- Enable Azure Monitor alerts (failed logins, high resource usage)
- Rotate secrets every 90 days
- Enable audit logging for PostgreSQL

---

## Disaster Recovery Plan

### Backup Configuration
- **PostgreSQL**: Automated backups every day, 15-day retention
- **Key Vault**: Soft delete enabled (90-day retention)
- **Container Registry**: Image tags preserved, 7-day soft delete

### Recovery Steps

#### Scenario 1: Container App Failure
```bash
# Restart the container app
az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg

# If restart fails, redeploy
./3_deploy_container_app.sh
```

#### Scenario 2: Database Corruption
```bash
# List available backups
az postgres flexible-server backup list \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db

# Restore to a specific point in time
az postgres flexible-server restore \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db \
  --source-server mas-n8n-postgress-db \
  --restore-time "2025-08-20T12:00:00Z"
```

#### Scenario 3: Complete Resource Group Deletion
```bash
# Run all deployment scripts in order
./1_create_workload_profile.sh
./2_build_image.sh
./3_deploy_container_app.sh

# Manually restore database from backup (if available)
# Reconfigure custom domain DNS
```

#### Scenario 4: Key Vault Secret Loss
```bash
# Secrets are auto-generated by deployment script
# Re-run deployment script to regenerate secrets
./3_deploy_container_app.sh

# Note: This will change passwords, requiring n8n admin password reset
```

### RTO/RPO Targets
- **RTO (Recovery Time Objective)**: 30 minutes (redeploy from scripts)
- **RPO (Recovery Point Objective)**: 24 hours (daily database backups)

---

## Monitoring and Alerts

### Key Metrics to Monitor
1. **Container App Health**: `az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg --query properties.runningStatus`
2. **Database Performance**: CPU, memory, connections, IOPS
3. **Application Logs**: Errors, warnings, failed authentications
4. **Resource Usage**: vCPU, memory, network egress
5. **Cost**: Daily spend, cost anomalies

### Recommended Alerts
- Container App goes to "Stopped" or "Failed" state
- Database CPU > 80% for 15 minutes
- Database storage > 80% full
- Failed login attempts > 10 in 5 minutes
- Cost exceeds $150/month

### Setting Up Alerts (Claude can help)
Ask Claude:
> "Set up alerts for n8n container app health and database performance"

---

## Version History

| Date | Version | Changes | By |
|------|---------|---------|-----|
| 2025-08-20 | 1.0 | Initial deployment, custom domain configured | brian.flett@masadvise.org |
| 2025-11-06 | 1.1 | Documentation created (CLAUDE.md) | Claude Code Assistant |
| 2025-11-06 | 1.2 | OAuth URL configuration fix, database password sync, environment variable management documentation | Claude Code Assistant |

---

## Useful Azure CLI Commands

```bash
# Check all resources in the resource group
az resource list --resource-group mas-n8n-rg --output table

# Get Container App details
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg

# View Container App logs (live)
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow

# Get Container App URL
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg --query "properties.configuration.ingress.fqdn" --output tsv

# Check PostgreSQL server status
az postgres flexible-server show --name mas-n8n-postgress-db --resource-group mas-n8n-rg

# List Key Vault secrets (names only)
az keyvault secret list --vault-name mas-n8n-kv --query "[].name" --output table

# Get secret value (requires Key Vault Secrets Officer role)
az keyvault secret show --vault-name mas-n8n-kv --name N8N-Admin-Password --query "value" --output tsv

# List images in ACR
az acr repository list --name masbgfn8nacr --output table

# Restart Container App
az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg

# Scale Container App
az containerapp update --name mas-n8n-app --resource-group mas-n8n-rg --min-replicas 1 --max-replicas 5

# Update environment variable
az containerapp update --name mas-n8n-app --resource-group mas-n8n-rg \
  --set-env-vars "N8N_LOG_LEVEL=debug"
```

---

## Contact and Support

**Primary Administrator**: brian.flett@masadvise.org
**Azure Subscription**: 088cc27a-c62c-49a5-908e-57e4610d6af6
**Organization**: MAS Advise Inc.

**When to Contact Claude**:
- Deployment issues or errors
- Configuration changes needed
- Performance optimization
- Security audits
- Cost analysis
- Troubleshooting application issues
- Scaling adjustments
- Disaster recovery scenarios

**When to Contact Azure Support**:
- Billing disputes
- Service outages (Azure platform)
- Quota increases (if needed)
- Subscription-level issues

---

## Additional Notes

### Why Azure Linux 3?
- **Lightweight**: Smaller image size (~300MB vs 1GB+ for Ubuntu)
- **Security**: Minimal attack surface, fewer vulnerabilities
- **Performance**: Optimized for Azure infrastructure
- **Cost**: Faster startup times = lower compute costs

### Why Consumption Workload Profile?
- **Cost-effective**: Pay only for actual usage (per-second billing)
- **Serverless**: No need to manage VMs or clusters
- **Auto-scaling**: Scales from 0 to 10 replicas based on demand
- **Integrated**: Built-in load balancing, SSL, monitoring

### Why PostgreSQL Over Other Databases?
- **n8n Compatibility**: Officially supported, well-tested
- **Azure Integration**: Fully managed, automatic backups
- **Performance**: Better than SQLite for concurrent workflows
- **Scalability**: Can upgrade to higher tiers as needed
- **Cost**: Burstable tier cheaper than MySQL/SQL Server equivalents

### Future Enhancements to Consider
1. **VNet Integration**: Private networking for enhanced security
2. **Azure Front Door**: Global CDN, DDoS protection, WAF
3. **Auto-scaling Rules**: Custom metrics-based scaling
4. **Read Replicas**: For PostgreSQL if high read load
5. **Azure AD Integration**: SSO for n8n authentication
6. **DevOps Pipeline**: Automated CI/CD for updates
7. **Multi-region**: Deploy to US East for redundancy

---

## Workflow Development with Claude Code

### Workflow Files Location
n8n workflows are stored as JSON files in:
```
/home/brian/workspace/docker/development/n8n-azure/workflows/
```

### Collaborative Workflow Development Process

**Step 1: Open the Workflow File**
Open the workflow JSON file in VS Code from the `workflows/` directory. This provides Claude with the complete workflow structure and node configuration.

**Step 2: Describe Your Challenge**
Tell Claude what you're trying to accomplish or what issue you're facing. For example:
- "I need to consolidate multiple Gmail messages into a single context for OpenAI"
- "How do I transform this data before sending it to the next node?"
- "I'm getting multiple items but need just one"

**Step 3: Claude Analyzes the Workflow**
Claude will:
1. Read the workflow JSON file to understand the current structure
2. Identify the relevant nodes and connections
3. Understand the data flow between nodes
4. Recognize the issue or optimization opportunity

**Step 4: Claude Provides Solutions**
Claude will suggest solutions with:
- Specific node types to use (Code, Aggregate, Function, etc.)
- Exact JavaScript/expression code for the solution
- Explanation of how data flows through the solution
- Examples of how to reference the data in downstream nodes

**Step 5: Claude Updates the Workflow File**
When you approve the solution, Claude can directly edit the workflow JSON file to:
- Add new nodes with proper configuration
- Update node parameters (like JavaScript code)
- Fix connections between nodes
- Rename nodes for clarity

**Step 6: Test in n8n**
After Claude updates the file:
1. Reload the workflow in n8n (the changes will appear automatically)
2. Test the workflow execution
3. Verify the data transformation worked as expected

### Example Session

**User**: "I have a Gmail node that returns multiple messages. I need to consolidate them into one formatted prompt for OpenAI."

**Claude**:
1. Reads the workflow JSON file
2. Identifies the Gmail node and its output structure
3. Suggests adding a Code node with consolidation logic
4. Provides the exact JavaScript code to consolidate messages
5. Updates the workflow JSON file directly
6. Explains how to reference the consolidated data in the AI Agent

**Result**: Workflow updated, ready to test immediately in n8n.

### Best Practices for Workflow Development with Claude

1. **Always open the workflow file first** - This gives Claude complete context
2. **Be specific about your goal** - Describe what data you have and what you need
3. **Share error messages** - If something isn't working, share the execution error
4. **Ask about data structure** - Claude can explain what data is available at each node
5. **Request explanations** - Ask Claude to explain how the solution works
6. **Iterate quickly** - Make small changes, test, then ask for next improvement

### Common Workflow Patterns Claude Can Help With

**Data Consolidation**:
- Combine multiple items into one
- Aggregate data across items
- Create formatted summaries

**Data Transformation**:
- Extract specific fields from complex objects
- Reformat data for API calls
- Convert between data structures

**Conditional Logic**:
- Route data based on conditions
- Filter items by criteria
- Handle different data scenarios

**API Integration**:
- Format requests for external APIs
- Parse and transform API responses
- Handle authentication and headers

**Error Handling**:
- Add fallback logic
- Validate data before processing
- Handle missing or malformed data

### Advantages of This Approach

✅ **Fast iteration** - No need to manually edit complex JSON
✅ **Accurate configuration** - Claude generates proper n8n node structure
✅ **Best practices** - Claude suggests optimal node types and patterns
✅ **Documentation** - Solutions are explained clearly
✅ **Version control** - Workflow files can be committed to git
✅ **No context switching** - Stay in VS Code, Claude updates files directly

### Tips for Success

- **Keep workflows in git** - Track changes to workflow files
- **Name nodes clearly** - Use descriptive names like "Consolidate Gmail Messages"
- **Test incrementally** - Test each change before adding more complexity
- **Ask for explanations** - Understand the solution, don't just copy it
- **Share sample data** - Show Claude example input/output if possible

---

**Last Updated**: November 7, 2025
**Documentation Maintained By**: Claude Code Assistant for MAS Advise Inc.
