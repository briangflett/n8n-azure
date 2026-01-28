# n8n Azure Monitoring & Cost Management

Guide for monitoring performance, setting up alerts, and managing costs for the n8n Azure deployment.

**Parent Project**: `/home/brian/workspace/deployments/azure/n8n-azure/CLAUDE.md`

---

## Cost Breakdown

### Estimated Monthly Costs

Based on current configuration:

| Resource | SKU/Tier | Estimated Cost |
|----------|----------|---------------|
| Container App (Consumption) | 2 vCPU, 4Gi RAM, 1-3 replicas | $30-60 |
| PostgreSQL Flexible Server | Standard_B1ms, 32GB | $25-30 |
| Container Registry | Basic tier | $5 |
| Key Vault | Standard, ~3 secrets | $1 |
| Log Analytics | Pay-as-you-go | $5-10 |
| **Total** | | **~$66-106/month** |

### Cost Optimization Opportunities

1. **Scale to Zero**: Reduce min replicas to 0 (saves ~$15-30/month)
   ```bash
   az containerapp update \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --min-replicas 0
   ```

2. **Reduce Max Replicas**: If traffic is consistently low
   ```bash
   az containerapp update \
     --name mas-n8n-app \
     --resource-group mas-n8n-rg \
     --max-replicas 1
   ```

3. **Database Reserved Instances**: 40% discount with 1-year commitment
   ```bash
   # View pricing options
   az postgres flexible-server show \
     --name mas-n8n-postgress-db \
     --resource-group mas-n8n-rg \
     --query "sku"
   ```

4. **Review Log Retention**: Reduce Log Analytics data retention
   ```bash
   az monitor log-analytics workspace update \
     --resource-group mas-n8n-rg \
     --workspace-name workspace-masn8nrgK7Sq \
     --retention-time 30  # Default is 90 days
   ```

---

## Monitoring Dashboards

### Azure Portal Access

**Resource Group Dashboard**:
```
https://portal.azure.com/#browse/resourcegroups → mas-n8n-rg
```

**Container App Metrics**:
```bash
# Open in browser
az containerapp show \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --query "id" -o tsv | \
  xargs -I {} echo "https://portal.azure.com/#@/resource/{}/metrics"
```

### Key Metrics to Monitor

1. **Container App Health**
   - Running status (should be "Running")
   - Replica count (should be between min/max)
   - HTTP requests per second
   - Response time (95th percentile)
   - Error rate

2. **Database Performance**
   - CPU percentage (alert if > 80%)
   - Memory percentage (alert if > 80%)
   - Active connections (alert if near max)
   - Storage used (alert if > 80%)
   - IOPS utilization

3. **Application Logs**
   - Error count (alert on spikes)
   - Failed authentications
   - Workflow execution failures

4. **Cost**
   - Daily spend
   - Cost anomalies
   - Budget alerts

---

## Setting Up Alerts

### Container App Health Alerts

Create alert for unhealthy container:

```bash
az monitor metrics alert create \
  --name "n8n-container-unhealthy" \
  --resource-group mas-n8n-rg \
  --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.App/containerApps/mas-n8n-app" \
  --condition "count Replicas < 1" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.Insights/actionGroups/email-alerts" \
  --description "n8n container app has no running replicas"
```

### Database CPU Alert

Alert when database CPU is consistently high:

```bash
az monitor metrics alert create \
  --name "n8n-db-high-cpu" \
  --resource-group mas-n8n-rg \
  --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/mas-n8n-postgress-db" \
  --condition "avg cpu_percent > 80" \
  --window-size 15m \
  --evaluation-frequency 5m \
  --description "PostgreSQL CPU usage above 80% for 15 minutes"
```

### Database Storage Alert

Alert when database storage is nearly full:

```bash
az monitor metrics alert create \
  --name "n8n-db-storage-full" \
  --resource-group mas-n8n-rg \
  --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/mas-n8n-postgress-db" \
  --condition "avg storage_percent > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --description "PostgreSQL storage usage above 80%"
```

### Cost Budget Alert

Create budget alert when spending exceeds threshold:

```bash
az consumption budget create \
  --resource-group mas-n8n-rg \
  --budget-name "n8n-monthly-budget" \
  --amount 150 \
  --time-grain Monthly \
  --start-date $(date +%Y-%m-01) \
  --notifications \
    threshold=80 \
    operator=GreaterThan \
    contact-emails="brian.flett@masadvise.org" \
    contact-roles="Owner"
```

---

## Querying Metrics

### Container App Metrics

**Current CPU and Memory Usage**:
```bash
az monitor metrics list \
  --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.App/containerApps/mas-n8n-app" \
  --metric "CpuPercentage,MemoryPercentage" \
  --interval PT1M
```

**HTTP Request Rate**:
```bash
az monitor metrics list \
  --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.App/containerApps/mas-n8n-app" \
  --metric "Requests" \
  --aggregation count \
  --interval PT5M
```

**Replica Count Over Time**:
```bash
az monitor metrics list \
  --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.App/containerApps/mas-n8n-app" \
  --metric "Replicas" \
  --interval PT15M
```

### Database Metrics

**Database CPU and Memory**:
```bash
az monitor metrics list \
  --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/mas-n8n-postgress-db" \
  --metric "cpu_percent,memory_percent" \
  --interval PT1M
```

**Active Connections**:
```bash
az monitor metrics list \
  --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/mas-n8n-postgress-db" \
  --metric "active_connections" \
  --interval PT1M
```

**Storage Usage**:
```bash
az monitor metrics list \
  --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/mas-n8n-postgress-db" \
  --metric "storage_percent,storage_used" \
  --interval PT1H
```

### Cost Analysis

**Current Month Costs**:
```bash
az consumption usage list \
  --start-date $(date +%Y-%m-01) \
  --end-date $(date +%Y-%m-%d) \
  | jq '.[] | select(.instanceName | contains("mas-n8n")) | {service: .meterCategory, cost: .pretaxCost}'
```

**Cost by Resource**:
```bash
az costmanagement query \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/mas-n8n-rg" \
  --time-period from='2026-01-01' to='2026-01-31' \
  --type Usage \
  --dataset-grouping name="ResourceId"
```

---

## Log Analytics Queries

### Access Log Analytics

```bash
# Get workspace ID
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group mas-n8n-rg \
  --workspace-name workspace-masn8nrgK7Sq \
  --query customerId -o tsv)

# Run query
az monitor log-analytics query \
  --workspace $WORKSPACE_ID \
  --analytics-query "ContainerAppConsoleLogs_CL | take 100"
```

### Useful Queries

**Error Rate in Last Hour**:
```kusto
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| where Log_s contains "ERROR" or Log_s contains "error"
| summarize ErrorCount = count() by bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

**Most Common Errors**:
```kusto
ContainerAppConsoleLogs_CL
| where Log_s contains "ERROR"
| extend ErrorMessage = extract("ERROR: (.*)", 1, Log_s)
| summarize Count = count() by ErrorMessage
| order by Count desc
| take 10
```

**Slow Requests** (> 5 seconds):
```kusto
ContainerAppConsoleLogs_CL
| where Log_s contains "request" and Log_s contains "ms"
| extend Duration = extract("(\\d+)ms", 1, Log_s)
| where toint(Duration) > 5000
| project TimeGenerated, Duration, Log_s
| order by toint(Duration) desc
```

---

## Performance Benchmarking

### Current Resource Allocation

```bash
az containerapp show \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --query "properties.template.containers[0].resources"
```

**Current**: 2 vCPU, 4Gi RAM

### Recommended Resource Changes

| Workload | vCPU | Memory | Cost Impact |
|----------|------|--------|-------------|
| Light (< 10 workflows) | 1 | 2Gi | -40% |
| Current (10-50 workflows) | 2 | 4Gi | Baseline |
| Heavy (50-100 workflows) | 4 | 8Gi | +80% |
| Very Heavy (100+ workflows) | 8 | 16Gi | +200% |

### Update Resources

```bash
# Increase resources for heavy workload
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --cpu 4 \
  --memory 8Gi

# Decrease for light workload
az containerapp update \
  --name mas-n8n-app \
  --resource-group mas-n8n-rg \
  --cpu 1 \
  --memory 2Gi
```

---

## Capacity Planning

### When to Scale Up

**Container App**:
- CPU consistently > 70%
- Memory consistently > 75%
- Request queue building up
- Response times degrading

**Database**:
- CPU consistently > 70%
- Active connections near limit (depends on tier)
- IOPS consistently maxed out
- Storage > 70% full

### Scaling Database

**Upgrade to General Purpose tier** (better performance):
```bash
az postgres flexible-server update \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db \
  --sku-name Standard_D2s_v3 \
  --tier GeneralPurpose
```

**Increase storage**:
```bash
az postgres flexible-server update \
  --resource-group mas-n8n-rg \
  --name mas-n8n-postgress-db \
  --storage-size 64
```

---

## Regular Monitoring Tasks

### Daily Checks

```bash
# Quick health check
az containerapp show --name mas-n8n-app --resource-group mas-n8n-rg \
  --query "properties.runningStatus" -o tsv

# Check for errors in last 24 hours
az containerapp logs show --name mas-n8n-app --resource-group mas-n8n-rg \
  | grep -i "error\|fatal" | tail -20
```

### Weekly Reviews

1. Review cost trends
2. Check resource utilization averages
3. Review error logs for patterns
4. Check database growth rate
5. Review backup status

### Monthly Tasks

1. **Cost optimization review**
2. **Performance trend analysis**
3. **Capacity planning assessment**
4. **Security audit** (see MAINTENANCE.md)
5. **Backup restoration test**

---

**Last Updated**: 2026-01-27
**Documentation**: Part of n8n Azure deployment documentation set
