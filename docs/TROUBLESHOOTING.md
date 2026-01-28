# n8n Azure Troubleshooting Guide

Solutions to common issues with the n8n Azure Container App deployment.

**Parent Project**: `/home/brian/workspace/deployments/azure/n8n-azure/CLAUDE.md`

---

## Quick Diagnostic Commands

```bash
# Check container app status
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
  --query "properties.runningStatus"

# View live logs
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow

# Check database status
az postgres flexible-server show --name mas-n8n-postgress-db --resource-group mas-n8n-rg

# Test secret retrieval
az keyvault secret show --vault-name mas-n8n-kv --name N8N-Admin-Password \
  --query "value" --output tsv
```

---

## Common Issues

### Issue: Container App Won't Start

**Symptoms**: Container App shows 'Provisioning' status and won't start

**Possible Causes**:
1. Image pull authentication failure
2. Key Vault secret access denied
3. Container startup errors
4. Database connection issues

**Troubleshooting Steps**:

1. **Check managed identity permissions**:
   ```bash
   # Verify AcrPull role for Container Registry
   az role assignment list \
     --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.ContainerRegistry/registries/masbgfn8nacr" \
     --assignee $(az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg --query "identity.principalId" -o tsv)

   # Verify Key Vault Secrets User role
   az role assignment list \
     --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.KeyVault/vaults/mas-n8n-kv" \
     --assignee $(az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg --query "identity.principalId" -o tsv)
   ```

2. **Check container logs**:
   ```bash
   az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --tail 100
   ```

3. **Force restart**:
   ```bash
   az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg
   ```

---

### Issue: Can't Access n8n Web Interface

**Symptoms**: Cannot reach n8n at n8n.masadvise.org

**Troubleshooting Steps**:

1. **Verify container is running**:
   ```bash
   az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
     --query "properties.runningStatus"
   ```

2. **Check ingress configuration**:
   ```bash
   az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
     --query "properties.configuration.ingress"
   ```

   Should show:
   - `external: true`
   - `targetPort: 5678`

3. **Verify custom domain binding**:
   ```bash
   az containerapp hostname list --name mas-n8n-app --resource-group mas-n8n-rg
   ```

4. **Check SSL certificate status**:
   ```bash
   az containerapp hostname list --name mas-n8n-app --resource-group mas-n8n-rg \
     --query "[].bindingType"
   ```

   Should show: `SniEnabled`

5. **Test DNS resolution**:
   ```bash
   dig n8n.masadvise.org
   nslookup n8n.masadvise.org
   ```

   Should resolve to: `mas-n8n-app.icyflower-6df495da.canadacentral.azurecontainerapps.io`

---

### Issue: Database Connection Failed

**Symptoms**: n8n logs show "password authentication failed" or connection timeout errors

**Troubleshooting Steps**:

1. **Check database is running**:
   ```bash
   az postgres flexible-server show --name mas-n8n-postgress-db --resource-group mas-n8n-rg \
     --query "state"
   ```

   Should show: `Ready`

2. **Verify firewall rules allow Container App IPs**:
   ```bash
   az postgres flexible-server firewall-rule list \
     --resource-group mas-n8n-rg \
     --name mas-n8n-postgress-db
   ```

3. **Test database connectivity from Container App**:
   ```bash
   # Exec into container (if possible)
   az containerapp exec --name mas-n8n-app --resource-group mas-n8n-rg --command /bin/sh

   # Inside container, test connection
   nc -zv mas-n8n-postgress-db.postgres.database.azure.com 5432
   ```

4. **Check password mismatch (common issue)**:
   ```bash
   # Get password from Key Vault
   DB_PASSWORD=$(az keyvault secret show \
     --vault-name mas-n8n-kv \
     --name N8N-DB-Password \
     --query "value" --output tsv)

   # Update PostgreSQL server with matching password
   az postgres flexible-server update \
     --resource-group mas-n8n-rg \
     --name mas-n8n-postgress-db \
     --admin-password "$DB_PASSWORD"

   # Restart container to reconnect
   az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg
   ```

---

### Issue: Database Password Mismatch

**Symptoms**: "password authentication failed for user brian" in logs

**Cause**: Deployment script generates new password in Key Vault but PostgreSQL still has old password

**Solution**:
```bash
# Step 1: Get current password from Key Vault
DB_PASSWORD=$(az keyvault secret show \
  --vault-name mas-n8n-kv \
  --name N8N-DB-Password \
  --query "value" \
  --output tsv)

# Step 2: Update PostgreSQL to match Key Vault
az postgres flexible-server update \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db \
  --admin-password "$DB_PASSWORD"

# Step 3: Force container restart
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --revision-suffix "dbfix$(date +%s)"
```

---

### Issue: Workflows Not Saving

**Symptoms**: Workflows created in n8n but not persisting after reload

**Possible Causes**:
1. Database connection failed
2. Database user lacks permissions
3. Encryption key changed

**Troubleshooting Steps**:

1. **Check database logs**:
   ```bash
   az postgres flexible-server server-logs list \
     --resource-group mas-n8n-rg \
     --name mas-n8n-postgress-db
   ```

2. **Verify encryption key is consistent**:
   ```bash
   # Check Key Vault secret hasn't changed
   az keyvault secret show-versions --vault-name mas-n8n-kv --name N8N-Encryption-Key
   ```

3. **Check n8n logs for database errors**:
   ```bash
   az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg \
     | grep -i "database\|postgres\|error"
   ```

---

### Issue: Environment Variables Not Taking Effect

**Symptoms**: Changed environment variable but container still using old value

**Cause**: Container Apps require revision update to pick up new environment variables

**Solution**:
```bash
# Method 1: Update single variable
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --set-env-vars "VARIABLE_NAME=new_value"

# Method 2: Force new revision
az containerapp revision copy \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg

# Verify variable is set
az containerapp show \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --query "properties.template.containers[0].env[?name=='VARIABLE_NAME']"
```

**Important**: When updating multiple variables, you MUST include ALL variables in the command, not just the ones you're changing. Otherwise, omitted variables will lose their values.

---

### Issue: Scaling Not Working

**Symptoms**: Container app not scaling up under load or not scaling down when idle

**Troubleshooting Steps**:

1. **Check current replica count**:
   ```bash
   az containerapp revision list \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --query "[].properties.replicas"
   ```

2. **Verify scaling configuration**:
   ```bash
   az containerapp show \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --query "properties.template.scale"
   ```

   Should show:
   - `minReplicas: 1`
   - `maxReplicas: 3`

3. **Check resource usage**:
   ```bash
   az monitor metrics list \
     --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.App/containerApps/mas-n8n-app" \
     --metric "CpuPercentage,MemoryPercentage"
   ```

4. **Update scaling rules if needed**:
   ```bash
   az containerapp update \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --min-replicas 0 \
     --max-replicas 5
   ```

---

### Issue: Custom Domain Certificate Issues

**Symptoms**: SSL/TLS errors when accessing n8n.masadvise.org

**Troubleshooting Steps**:

1. **Check certificate status**:
   ```bash
   az containerapp hostname list \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg
   ```

2. **Verify DNS CNAME record**:
   ```bash
   dig CNAME n8n.masadvise.org
   ```

   Should point to: `mas-n8n-app.icyflower-6df495da.canadacentral.azurecontainerapps.io`

3. **Re-provision certificate if needed**:
   ```bash
   # Remove binding
   az containerapp hostname delete \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --hostname n8n.masadvise.org

   # Re-add with new certificate
   az containerapp hostname bind \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --hostname n8n.masadvise.org \
     --environment mas-n8n-workload-profile
   ```

---

## Performance Issues

### Issue: Slow Response Times

**Investigation Steps**:

1. **Check resource usage**:
   ```bash
   az containerapp show \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --query "properties.template.containers[0].resources"
   ```

2. **Review database performance**:
   ```bash
   az postgres flexible-server show \
     --name mas-n8n-postgress-db \
     --resource-group mas-n8n-rg \
     --query "{sku:sku.name,storage:storage.storageSizeGB}"
   ```

3. **Check for errors in logs**:
   ```bash
   az containerapp logs show \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     | grep -i "error\|timeout\|failed"
   ```

**Optimization Options**:
- Increase container resources (vCPU/memory)
- Upgrade database tier (from Burstable to General Purpose)
- Add database read replicas
- Optimize workflow execution

---

## Emergency Procedures

### Full Service Restart

If n8n is completely unresponsive:

```bash
# 1. Stop traffic
az containerapp ingress disable --name mas-n8n-app --resource-group mas-n8n-rg

# 2. Restart container
az containerapp restart --name mas-n8n-app --resource-group mas-n8n-rg

# 3. Wait for healthy state
sleep 60

# 4. Re-enable traffic
az containerapp ingress enable --name mas-n8n-app --resource-group mas-n8n-rg \
  --type external --target-port 5678 --transport auto
```

### Rollback to Previous Revision

If new deployment is causing issues:

```bash
# List revisions
az containerapp revision list \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --query "[].{name:name,active:properties.active}"

# Activate previous revision
az containerapp revision activate \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --revision <previous-revision-name>

# Deactivate problematic revision
az containerapp revision deactivate \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --revision <problematic-revision-name>
```

---

## Getting Help

### Useful Log Queries

```bash
# Last 100 log entries
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --tail 100

# Follow logs in real-time
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg --follow

# Filter by error severity
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg \
  | grep -E "ERROR|FATAL"

# Search for specific term
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg \
  | grep "database"
```

### Azure Portal Links

- **Resource Group**: https://portal.azure.com/#browse/resourcegroups → `mas-n8n-rg`
- **Container App**: https://portal.azure.com → Search "mas-n8n-app"
- **Key Vault**: https://portal.azure.com → Search "mas-n8n-kv"
- **PostgreSQL**: https://portal.azure.com → Search "mas-n8n-postgress-db"

---

**Last Updated**: 2026-01-27
**Documentation**: Part of n8n Azure deployment documentation set
