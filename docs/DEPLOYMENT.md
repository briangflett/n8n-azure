# n8n Azure Deployment Guide

Complete guide for deploying n8n to Azure Container Apps.

**Parent Project**: `/home/brian/workspace/deployments/azure/n8n-azure/CLAUDE.md`

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

## Container App Configuration

### `mas-n8n-app`

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
- System-assigned managed identity
- Non-root container execution
- Key Vault secret references (no secrets in environment variables)
- Basic authentication enabled (username: `brian`)
- SSL/TLS with custom domain certificate

**Custom Domain**:
- Domain: `n8n.masadvise.org`
- Managed certificate: Auto-provisioned Azure managed certificate
- Binding: SNI Enabled

---

## PostgreSQL Flexible Server

### `mas-n8n-postgress-db`

**Configuration**:
- **SKU**: Standard_B1ms (Burstable tier) - Cost-optimized
- **Storage**: 32 GB (120 IOPS, P4 tier)
- **PostgreSQL Version**: 14.19
- **Admin User**: `brian`
- **Database Name**: `n8n`
- **FQDN**: `mas-n8n-postgress-db.postgres.database.azure.com`
- **High Availability**: Disabled (cost optimization)
- **Geo-Redundant Backup**: Disabled
- **Backup Retention**: 15 days
- **Availability Zone**: 2

**Network Configuration**:
- **Public Access**: Enabled (0.0.0.0 - firewall rules required)
- **SSL**: Enabled but not enforced
- **Connection Timeout**: 3000ms

---

## Key Vault Configuration

### `mas-n8n-kv`

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

---

## Container Registry

### `masbgfn8nacr`

**Configuration**:
- **Login Server**: `masbgfn8nacr.azurecr.io`
- **SKU**: Basic tier
- **Admin User**: Enabled (fallback authentication)
- **Image**: `mas-n8n-image:latest`

**Security**:
- Azure AD authentication enabled
- Managed identity authentication configured
- Public network access enabled

---

## Container App Environment

### `mas-n8n-workload-profile`

**Configuration**:
- **Default Domain**: `icyflower-6df495da.canadacentral.azurecontainerapps.io`
- **Static IP**: `4.248.208.42`
- **Workload Profile**: Consumption (serverless)
- **Logging**: Log Analytics workspace integration

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
- After rebuilding Docker image
- Scaling adjustments

**Smart Features**:
- **Idempotent**: Safe to run multiple times, skips existing resources
- **RBAC retry logic**: Handles Azure RBAC propagation delays
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

---

## Initial Deployment Process

### Setup (August 20, 2025)

1. **Cloned Repository**:
   ```bash
   git clone https://github.com/oriziv5/n8n-azure.git
   cd n8n-azure
   ```

2. **Customized Configuration**:
   - Updated all scripts with MAS-specific naming (`mas-n8n-*`)
   - Changed location to Canada Central
   - Configured custom domain `n8n.masadvise.org`
   - Set timezone to Asia/Jerusalem
   - Optimized database to Burstable tier for cost savings

3. **Ran Deployment Scripts**:
   ```bash
   ./1_create_workload_profile.sh
   ./2_build_image.sh
   ./3_deploy_container_app.sh
   ```

4. **Post-Deployment**:
   - Configured DNS CNAME: `n8n.masadvise.org` → container app FQDN
   - Azure automatically provisioned managed SSL certificate
   - Verified n8n accessible at https://n8n.masadvise.org

---

## Key Decisions Made

**Database**:
- PostgreSQL 14 (stable, well-supported by n8n)
- Burstable tier (Standard_B1ms) for cost optimization
- Disabled high availability (not critical for workflow automation)
- 15-day backup retention (adequate for recovery)

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
- Node.js 22.12.0 (meets n8n requirements)
- Non-root user execution (security best practice)
- Latest n8n version (auto-updated)

---

## Updating n8n Version

To update n8n to the latest version:

```bash
cd /home/brian/workspace/deployments/azure/n8n-azure

# Rebuild image with latest n8n
./2_build_image.sh

# Redeploy container app with new image
./3_deploy_container_app.sh

# Verify deployment
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg --query "properties.runningStatus"

# Check logs for any issues
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow
```

---

**Last Updated**: 2026-01-27
**Documentation**: Part of n8n Azure deployment documentation set
