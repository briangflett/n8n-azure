# n8n Azure Deployment - Claude Code Assistant Guide

**Production n8n deployment on Azure Container Apps for MAS Advise Inc.**

---

## ⚠️ Quick Status

**Deployment Status**: ✅ **LIVE IN PRODUCTION**
- **Primary URL**: https://n8n.masadvise.org
- **Azure FQDN**: https://mas-n8n-app.icyflower-6df495da.canadacentral.azurecontainerapps.io
- **Location**: Canada Central
- **Created**: August 20, 2025

---

## Quick Reference

### Essential Commands

```bash
# View live logs
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow

# Check status
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
  --query "properties.runningStatus"

# Restart container
az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg

# Update n8n version
cd /home/brian/workspace/deployments/azure/n8n-azure
./2_build_image.sh
./3_deploy_container_app.sh
```

### Azure Resources

| Resource | Type | Purpose |
|----------|------|---------|
| `mas-n8n-app` | Container App | n8n application |
| `mas-n8n-postgress-db` | PostgreSQL Flexible Server | Database |
| `mas-n8n-kv` | Key Vault | Secrets |
| `masbgfn8nacr` | Container Registry | Docker images |

**Resource Group**: `mas-n8n-rg` (Canada Central)

---

## Documentation

### Detailed Guides

For comprehensive documentation, see the `docs/` directory:

📂 **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**
- Complete deployment procedures
- Azure resource configuration
- Deployment scripts explained
- Environment variables
- Initial setup process

📂 **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**
- Common issues and solutions
- Container app problems
- Database connection issues
- Performance troubleshooting
- Emergency procedures

📂 **[docs/MONITORING.md](docs/MONITORING.md)**
- Cost breakdown and optimization
- Setting up alerts
- Querying metrics
- Performance benchmarking
- Capacity planning

📂 **[docs/MAINTENANCE.md](docs/MAINTENANCE.md)**
- Regular maintenance schedule
- Backup and disaster recovery
- Updating n8n version
- Security maintenance
- Database maintenance

---

## Common Operations

### 1. Viewing Logs

```bash
# Live tail
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow

# Last 100 lines
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --tail 100

# Filter errors
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg \
  | grep -i "error\|fatal"
```

### 2. Updating n8n

```bash
cd /home/brian/workspace/deployments/azure/n8n-azure

# Step 1: Rebuild image with latest n8n
./2_build_image.sh

# Step 2: Deploy updated image
./3_deploy_container_app.sh

# Step 3: Verify
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
  --query "properties.runningStatus"
```

**See**: [docs/MAINTENANCE.md](docs/MAINTENANCE.md) for detailed update procedures

### 3. Scaling Configuration

```bash
# Increase max replicas
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --max-replicas 5

# Scale to zero for cost savings
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --min-replicas 0
```

### 4. Database Password Sync

**Common issue**: If deployment script runs, it generates new Key Vault password but PostgreSQL keeps old password.

**Solution**:
```bash
# Get password from Key Vault
DB_PASSWORD=$(az keyvault secret show \
  --vault-name mas-n8n-kv \
  --name N8N-DB-Password \
  --query "value" --output tsv)

# Update PostgreSQL to match
az postgres flexible-server update \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db \
  --admin-password "$DB_PASSWORD"

# Restart container
az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg
```

**See**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions

### 5. Checking Costs

```bash
# Current month costs
az consumption usage list \
  --start-date $(date +%Y-%m-01) \
  --end-date $(date +%Y-%m-%d) \
  | jq '.[] | select(.instanceName | contains("mas-n8n")) | {service: .meterCategory, cost: .pretaxCost}'
```

**See**: [docs/MONITORING.md](docs/MONITORING.md) for cost optimization

---

## Architecture Overview

### Components

**Container App**: `mas-n8n-app`
- Image: Azure Linux 3 + Node.js 22.12.0 + n8n (latest)
- Resources: 2 vCPU, 4Gi RAM
- Scaling: 1-3 replicas
- Authentication: Managed identity

**Database**: `mas-n8n-postgress-db`
- PostgreSQL 14.19
- Burstable tier (Standard_B1ms)
- 32GB storage, 15-day backups

**Secrets**: `mas-n8n-kv` (Key Vault)
- n8n encryption key
- Database password
- Admin password

### Technology Decisions

**Why Azure Linux 3**: Lightweight, optimized for Azure, minimal attack surface

**Why Burstable Database**: Cost-effective ($25-30/month vs $100+ for General Purpose)

**Why Consumption Profile**: Pay-per-use, auto-scaling, serverless convenience

**Estimated Monthly Cost**: $66-106

**See**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete architecture details

---

## File Locations

### Deployment Scripts

```
/home/brian/workspace/deployments/azure/n8n-azure/
├── 1_create_workload_profile.sh    # Create infrastructure
├── 2_build_image.sh                # Build Docker image
├── 3_deploy_container_app.sh       # Deploy/update container
├── Dockerfile.azurelinux           # Image definition
└── docs/                           # Detailed documentation
```

### Configuration

- **Database Credentials**: Azure Key Vault (`mas-n8n-kv`)
- **Custom Domain**: n8n.masadvise.org (auto SSL)
- **Logs**: Log Analytics workspace (`workspace-masn8nrgK7Sq`)

---

## Security

**Current Implementation**:
✅ Managed identity (no credentials in code)
✅ RBAC-based Key Vault
✅ Auto-generated strong secrets
✅ SSL/TLS with managed certificates
✅ Non-root container execution
✅ Basic authentication enabled

**See**: [docs/MAINTENANCE.md](docs/MAINTENANCE.md) for security maintenance procedures

---

## Troubleshooting Quick Links

**Container won't start**: [docs/TROUBLESHOOTING.md#container-app-wont-start](docs/TROUBLESHOOTING.md)

**Database connection failed**: [docs/TROUBLESHOOTING.md#database-connection-failed](docs/TROUBLESHOOTING.md)

**Workflows not saving**: [docs/TROUBLESHOOTING.md#workflows-not-saving](docs/TROUBLESHOOTING.md)

**Password mismatch**: [docs/TROUBLESHOOTING.md#database-password-mismatch](docs/TROUBLESHOOTING.md)

**Environment variables not updating**: [docs/TROUBLESHOOTING.md#environment-variables-not-taking-effect](docs/TROUBLESHOOTING.md)

---

## n8n Workflow Development

**Workflows Repository**: `/home/brian/workspace/workflows/`

**Workflow Repositories**:
- **Allard Prize**: `/home/brian/workspace/workflows/allard-prize/`
- **Personal**: `/home/brian/workspace/workflows/personal/`

**Note**: Both use the same n8n instance (https://n8n.masadvise.org)

---

## Useful Azure CLI Commands

```bash
# List all resources
az resource list --resource-group mas-n8n-rg --output table

# Get container app URL
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
  --query "properties.configuration.ingress.fqdn" --output tsv

# Check database status
az postgres flexible-server show --name mas-n8n-postgress-db \
  --resource-group mas-n8n-rg --query "state"

# List Key Vault secrets
az keyvault secret list --vault-name mas-n8n-kv --query "[].name" --output table

# List container images
az acr repository list --name masbgfn8nacr --output table

# Scale container
az containerapp update --name mas-n8n-app --resource-group mas-n8n-rg \
  --min-replicas 1 --max-replicas 5
```

---

## Version History

| Date | Version | Changes | By |
|------|---------|---------|-----|
| 2025-08-20 | 1.0 | Initial deployment, custom domain configured | brian.flett@masadvise.org |
| 2025-11-06 | 1.1 | Documentation created (CLAUDE.md) | Claude Code |
| 2025-11-06 | 1.2 | OAuth URL config fix, password sync | Claude Code |
| 2025-11-07 | 1.3 | Security hardening: removed hardcoded credentials | Claude Code |
| 2025-12-03 | 1.4 | Workflow repositories separation | Claude Code |
| 2026-01-27 | 1.5 | Documentation restructure: extracted to docs/ | Claude Code |

---

## Contact

**Primary Administrator**: brian.flett@masadvise.org
**Azure Subscription**: 088cc27a-c62c-49a5-908e-57e4610d6af6
**Organization**: MAS Advise Inc.

**For Help With**:
- Deployment issues → [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- Cost optimization → [docs/MONITORING.md](docs/MONITORING.md)
- Updates/maintenance → [docs/MAINTENANCE.md](docs/MAINTENANCE.md)
- Configuration → [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

---

**Last Updated**: 2026-01-27
**Documentation**: This is the main entry point. See `docs/` for detailed guides.
