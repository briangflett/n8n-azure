# n8n Azure Deployment - Claude Code Guide

**Production n8n on Azure Container Apps for MAS Advise Inc.**

## Quick Status

- **URL**: https://n8n.masadvise.org
- **Resource Group**: `mas-n8n-rg` (Canada Central)
- **Version**: n8n 2.11.4 on Azure Linux 3 + Node.js 24

## Azure Resources

| Resource | Type |
|----------|------|
| `mas-n8n-app` | Container App (2 vCPU, 4Gi RAM) |
| `mas-n8n-postgress-db` | PostgreSQL Flexible Server |
| `mas-n8n-kv` | Key Vault |
| `masbgfn8nacr` | Container Registry |

## Essential Commands

```bash
# View logs
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow

# Restart
az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg

# Build and deploy (from this directory)
az acr build --registry masbgfn8nacr --image mas-n8n-image:$(date +%Y%m%d) --file Dockerfile.azurelinux .
az containerapp update --name mas-n8n-app --resource-group mas-n8n-rg \
  --image masbgfn8nacr.azurecr.io/mas-n8n-image:$(date +%Y%m%d)
```

## Key Files

```
├── Dockerfile.azurelinux           # Image definition
├── docker-entrypoint.sh            # Startup script (installs community nodes)
├── 1_create_workload_profile.sh    # Create infrastructure
├── 2_build_image.sh                # Build Docker image (needs local Docker)
├── 3_deploy_container_app_MAS.sh   # Deploy/update container (MAS production)
├── 3_deploy_container_app.sh       # Deploy template version
└── docs/                           # Detailed documentation
```

## Important Gotchas

- **Image tagging**: Always use a unique tag (e.g. date-based) when deploying. Using `:latest` won't trigger a new revision if the tag name hasn't changed.
- **Community nodes**: Managed via `docker-entrypoint.sh`. The entrypoint installs nodes into `/data/.n8n/nodes/` on startup. To add/update nodes, edit the entrypoint script, rebuild, and deploy. See [docs/MAINTENANCE.md](docs/MAINTENANCE.md).
- **Build without Docker**: WSL lacks Docker Desktop. Use `az acr build` for cloud builds instead of `2_build_image.sh`.
- **DB password sync**: Running `3_deploy_container_app_MAS.sh` generates a new Key Vault password but PostgreSQL keeps the old one. See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).
- **OAuth callbacks**: n8n v2 requires `N8N_SKIP_AUTH_ON_OAUTH_CALLBACK=true` (set in deploy script).

## Documentation

- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Azure resource config, env vars, setup
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[docs/MONITORING.md](docs/MONITORING.md)** - Cost breakdown, alerts, metrics
- **[docs/MAINTENANCE.md](docs/MAINTENANCE.md)** - Updates, backups, community nodes, security

## Workflow Repositories

- **Allard Prize**: `/home/brian/workspace/workflows/allard-prize/`
- **Personal**: `/home/brian/workspace/workflows/personal/`

---

## Session Lifecycle

- **Start**: `/bootstrap` (loads Klaus context, checks pending handoffs)
- **End**: `/wrapup` (logs summary, updates SESSIONS, handles handoffs, checks git)

Klaus capabilities are provided via the globally available `klaus-workflows`, `bootstrap`, and `wrapup` skills.

---

**Last Updated**: 2026-03-15
