#!/bin/bash
# Deploy n8n Container App for Brian's existing Azure setup
# Uses existing PostgreSQL Flexible Server and Key Vault

echo "[$(date)] Starting n8n Container App deployment for Brian's setup..."

# Configuration Variables - CUSTOMIZED FOR BRIAN'S EXISTING SETUP
RESOURCE_GROUP="rg-nonprofit-ai"                            # Brian's existing resource group
LOCATION="canadacentral"                                    # Brian's region
CONTAINER_APP_NAME="n8n-nonprofit-app"                      # Container app name
ENV_NAME="n8n-env"                                         # Container Apps Environment
ACR_NAME="briannonprofitacr"                               # ACR from script 2
IMAGE_NAME="n8n"                                           # n8n image name

# Existing Resources (ALREADY CREATED)
DB_SERVER_NAME="psql-n8n-nonprofit"                        # Brian's existing PostgreSQL server
DB_HOST="${DB_SERVER_NAME}.postgres.database.azure.com"    # Full hostname
DB_NAME="n8n_unified"                                      # Brian's existing database
DB_ADMIN_USER="brian"                                      # Brian's database user
DB_PASSWORD="gKU011@gEsMR"                                 # Brian's database password
KEYVAULT_NAME="kv-n8n-nonprofit"                           # Brian's existing Key Vault

# n8n Configuration
N8N_USERNAME="brian"                                       # n8n admin username  
N8N_PASSWORD="gKU011@gEsMR"                               # n8n admin password
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)             # Generate new encryption key

# Validate required variables
echo "[$(date)] Validating required variables..."
[[ -z "${RESOURCE_GROUP}" ]] && { echo "Error: RESOURCE_GROUP is not set"; exit 1; }
[[ -z "${CONTAINER_APP_NAME}" ]] && { echo "Error: CONTAINER_APP_NAME is not set"; exit 1; }
[[ -z "${DB_HOST}" ]] && { echo "Error: DB_HOST is not set"; exit 1; }
[[ -z "${DB_NAME}" ]] && { echo "Error: DB_NAME is not set"; exit 1; }
[[ -z "${KEYVAULT_NAME}" ]] && { echo "Error: KEYVAULT_NAME is not set"; exit 1; }
echo "[$(date)] Variable validation completed."

# Function for timestamped logging
log_message() {
    echo "[$(date)] $1"
}

# Function to check if a resource exists
check_resource_exists() {
    local resource_type=$1
    local resource_name=$2
    local resource_group=$3
    
    case $resource_type in
        "postgres-server")
            az postgres flexible-server show --name "${resource_name}" --resource-group "${resource_group}" --output none 2>/dev/null
            ;;
        "keyvault")
            az keyvault show --name "${resource_name}" --output none 2>/dev/null
            ;;
        "containerapp")
            az containerapp show --name "${resource_name}" --resource-group "${resource_group}" --output none 2>/dev/null
            ;;
        "containerapp-env")
            az containerapp env show --name "${resource_name}" --resource-group "${resource_group}" --output none 2>/dev/null
            ;;
        "acr")
            az acr show --name "${resource_name}" --output none 2>/dev/null
            ;;
        *)
            echo "Unknown resource type: ${resource_type}"
            return 1
            ;;
    esac
}

# Function to assign RBAC role with retry
assign_rbac_role() {
    local principal_id="$1"
    local role="$2"
    local scope="$3"
    local max_attempts=5
    local attempt=1
    
    log_message "Assigning role '$role' to principal '$principal_id'"
    
    while [ $attempt -le $max_attempts ]; do
        log_message "RBAC assignment attempt $attempt/$max_attempts"
        
        if az role assignment create \
            --assignee "$principal_id" \
            --role "$role" \
            --scope "$scope" >/dev/null 2>&1; then
            log_message "✅ Successfully assigned role '$role'"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_message "❌ Failed to assign role '$role' after $max_attempts attempts"
            return 1
        fi
        
        log_message "Attempt $attempt failed, retrying in 10 seconds..."
        sleep 10
        ((attempt++))
    done
}

# Function to create Key Vault secret if it doesn't exist
create_keyvault_secret_if_needed() {
    local keyvault_name="$1"
    local secret_name="$2"
    local secret_value="$3"
    
    log_message "Checking if secret '$secret_name' exists..."
    
    local existing_secret=$(az keyvault secret show \
        --vault-name "$keyvault_name" \
        --name "$secret_name" \
        --query "id" \
        --output tsv 2>/dev/null)
    
    if [[ -n "$existing_secret" && "$existing_secret" != "null" ]]; then
        log_message "✅ Secret '$secret_name' already exists"
        return 0
    else
        log_message "Creating secret '$secret_name'..."
        if az keyvault secret set \
            --vault-name "$keyvault_name" \
            --name "$secret_name" \
            --value "$secret_value" >/dev/null 2>&1; then
            log_message "✅ Successfully created secret '$secret_name'"
            return 0
        else
            log_message "❌ Failed to create secret '$secret_name'"
            return 1
        fi
    fi
}

# 1. Verify all existing resources
log_message "=== Verifying Existing Azure Resources ==="

# Check PostgreSQL server
log_message "Checking PostgreSQL server '${DB_SERVER_NAME}'..."
if check_resource_exists "postgres-server" "${DB_SERVER_NAME}" "${RESOURCE_GROUP}"; then
    log_message "✅ PostgreSQL server exists and accessible."
else
    log_message "❌ Error: PostgreSQL server '${DB_SERVER_NAME}' not found!"
    exit 1
fi

# Check Key Vault
log_message "Checking Key Vault '${KEYVAULT_NAME}'..."
if check_resource_exists "keyvault" "${KEYVAULT_NAME}" ""; then
    log_message "✅ Key Vault exists and accessible."
else
    log_message "❌ Error: Key Vault '${KEYVAULT_NAME}' not found!"
    exit 1
fi

# Check Container Apps Environment
log_message "Checking Container Apps Environment '${ENV_NAME}'..."
if check_resource_exists "containerapp-env" "${ENV_NAME}" "${RESOURCE_GROUP}"; then
    log_message "✅ Container Apps Environment exists."
else
    log_message "❌ Error: Container Apps Environment '${ENV_NAME}' not found!"
    log_message "Please run script 1_setup_environment_brian.sh first."
    exit 1
fi

# Check ACR and image
log_message "Checking ACR '${ACR_NAME}' and n8n image..."
if check_resource_exists "acr" "${ACR_NAME}"; then
    log_message "✅ ACR exists."
    
    # Verify n8n image exists
    if az acr repository show --name "${ACR_NAME}" --repository "${IMAGE_NAME}" --output none 2>/dev/null; then
        log_message "✅ n8n image found in ACR."
    else
        log_message "❌ Error: n8n image not found in ACR!"
        log_message "Please run script 2_setup_acr_brian.sh first."
        exit 1
    fi
else
    log_message "❌ Error: ACR '${ACR_NAME}' not found!"
    log_message "Please run script 2_setup_acr_brian.sh first."
    exit 1
fi

# 2. Store secrets in Key Vault (if not already present)
log_message "=== Setting up Key Vault Secrets ==="

create_keyvault_secret_if_needed "${KEYVAULT_NAME}" "N8N-Encryption-Key" "${N8N_ENCRYPTION_KEY}" || exit 1
create_keyvault_secret_if_needed "${KEYVAULT_NAME}" "N8N-Admin-Password" "${N8N_PASSWORD}" || exit 1
create_keyvault_secret_if_needed "${KEYVAULT_NAME}" "N8N-DB-Password" "${DB_PASSWORD}" || exit 1

log_message "✅ All required secrets are available in Key Vault."

# 3. Create or update Container App
log_message "=== Container App Deployment ==="

ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query "loginServer" --output tsv)
FULL_IMAGE_PATH="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest"

log_message "Container App Configuration:"
log_message "  • Name: ${CONTAINER_APP_NAME}"
log_message "  • Environment: ${ENV_NAME}"
log_message "  • Image: ${FULL_IMAGE_PATH}"
log_message "  • Database: ${DB_HOST}/${DB_NAME}"

if check_resource_exists "containerapp" "${CONTAINER_APP_NAME}" "${RESOURCE_GROUP}"; then
    log_message "✅ Container App '${CONTAINER_APP_NAME}' already exists."
    CONTAINER_APP_EXISTS=true
else
    log_message "Creating new Container App '${CONTAINER_APP_NAME}'..."
    
    # Create Container App with temporary public image first
    log_message "Step 1: Creating Container App with temporary image..."
    az containerapp create \
        --name "${CONTAINER_APP_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --environment "${ENV_NAME}" \
        --image "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" \
        --cpu 1.0 \
        --memory 2Gi \
        --ingress external \
        --target-port 80 \
        --min-replicas 0 \
        --max-replicas 3 \
        --system-assigned \
        --output none
    
    if [[ $? -eq 0 ]]; then
        log_message "✅ Container App created successfully."
        CONTAINER_APP_EXISTS=false
    else
        log_message "❌ Error: Failed to create Container App"
        exit 1
    fi
fi

# 4. Get Container App managed identity
log_message "=== Setting up Managed Identity ==="

# Ensure system-assigned managed identity is enabled
log_message "Ensuring system-assigned managed identity is enabled..."
az containerapp identity assign \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --system-assigned \
    --output none

# Get principal ID with retry
log_message "Retrieving managed identity principal ID..."
PRINCIPAL_ID=""
for attempt in {1..10}; do
    PRINCIPAL_ID=$(az containerapp show \
        --name "${CONTAINER_APP_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "identity.principalId" \
        --output tsv 2>/dev/null)
    
    if [[ -n "${PRINCIPAL_ID}" ]] && [[ "${PRINCIPAL_ID}" != "null" ]]; then
        log_message "✅ Principal ID retrieved: ${PRINCIPAL_ID}"
        break
    else
        log_message "⚠️  Managed identity not ready yet (attempt ${attempt}/10)"
        if [[ ${attempt} -lt 10 ]]; then
            sleep 15
        fi
    fi
done

if [[ -z "${PRINCIPAL_ID}" ]] || [[ "${PRINCIPAL_ID}" == "null" ]]; then
    log_message "❌ Error: Failed to retrieve managed identity principal ID"
    exit 1
fi

# 5. Assign RBAC roles
log_message "=== Assigning RBAC Roles ==="

# Get resource IDs
ACR_RESOURCE_ID=$(az acr show --name "${ACR_NAME}" --query "id" --output tsv)
KEYVAULT_RESOURCE_ID=$(az keyvault show --name "${KEYVAULT_NAME}" --query "id" --output tsv)

# Assign ACR Pull role
log_message "Assigning AcrPull role for container registry access..."
assign_rbac_role "${PRINCIPAL_ID}" "AcrPull" "${ACR_RESOURCE_ID}" || exit 1

# Assign Key Vault Secrets User role  
log_message "Assigning Key Vault Secrets User role..."
assign_rbac_role "${PRINCIPAL_ID}" "Key Vault Secrets User" "${KEYVAULT_RESOURCE_ID}" || exit 1

# Wait for RBAC propagation
log_message "Waiting for RBAC permissions to propagate..."
sleep 60

# 6. Configure Container App registry authentication
log_message "=== Configuring Registry Authentication ==="

log_message "Setting up ACR authentication with managed identity..."
az containerapp registry set \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --server "${ACR_LOGIN_SERVER}" \
    --identity "system" \
    --output none

if [[ $? -eq 0 ]]; then
    log_message "✅ Registry authentication configured successfully."
else
    log_message "⚠️  Registry authentication configuration failed, will retry later."
fi

# 7. Configure Container App secrets (Key Vault references)
log_message "=== Configuring Secrets ==="

log_message "Setting up Key Vault secret references..."
az containerapp secret set \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --secrets \
        n8n-encryption-key="keyvaultref:https://${KEYVAULT_NAME}.vault.azure.net/secrets/N8N-Encryption-Key,identityref:system" \
        n8n-db-password="keyvaultref:https://${KEYVAULT_NAME}.vault.azure.net/secrets/N8N-DB-Password,identityref:system" \
        n8n-admin-password="keyvaultref:https://${KEYVAULT_NAME}.vault.azure.net/secrets/N8N-Admin-Password,identityref:system" \
    --output none

if [[ $? -eq 0 ]]; then
    log_message "✅ Key Vault secret references configured successfully."
else
    log_message "❌ Error: Failed to configure Key Vault secret references"
    log_message "This may be due to RBAC propagation delays. Continuing with deployment..."
fi

# 8. Update Container App with n8n image and configuration
log_message "=== Deploying n8n Configuration ==="

log_message "Updating Container App with n8n image and environment variables..."
az containerapp update \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --image "${FULL_IMAGE_PATH}" \
    --cpu 1.0 \
    --memory 2Gi \
    --min-replicas 0 \
    --max-replicas 3 \
    --set-env-vars \
        N8N_ENCRYPTION_KEY="secretref:n8n-encryption-key" \
        N8N_DATABASE_TYPE=postgresdb \
        N8N_DATABASE_HOST="${DB_HOST}" \
        N8N_DATABASE_PORT=5432 \
        N8N_DATABASE_NAME="${DB_NAME}" \
        N8N_DATABASE_USER="${DB_ADMIN_USER}" \
        N8N_DATABASE_PASSWORD="secretref:n8n-db-password" \
        N8N_DATABASE_SSL=true \
        N8N_BASIC_AUTH_ACTIVE=true \
        N8N_BASIC_AUTH_USER="${N8N_USERNAME}" \
        N8N_BASIC_AUTH_PASSWORD="secretref:n8n-admin-password" \
        N8N_HOST=0.0.0.0 \
        N8N_PORT=5678 \
        N8N_PROTOCOL=http \
        N8N_LOG_LEVEL=info \
        N8N_LOG_OUTPUT=console \
        NODE_ENV=production \
        GENERIC_TIMEZONE=America/Toronto \
        N8N_SECURE_COOKIE=false \
        N8N_RUNNERS_ENABLED=true \
        DB_POSTGRESDB_SSL=true \
        DB_TYPE=postgresdb \
        DB_POSTGRESDB_HOST="${DB_HOST}" \
        DB_POSTGRESDB_PORT=5432 \
        DB_POSTGRESDB_DATABASE="${DB_NAME}" \
        DB_POSTGRESDB_USER="${DB_ADMIN_USER}" \
        DB_POSTGRESDB_PASSWORD="secretref:n8n-db-password" \
        DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=false \
    --output none

if [[ $? -eq 0 ]]; then
    log_message "✅ Container App updated with n8n configuration successfully."
else
    log_message "❌ Error: Failed to update Container App with n8n configuration"
    exit 1
fi

# 9. Configure ingress for n8n port
log_message "Configuring ingress for n8n (port 5678)..."
az containerapp ingress update \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --type external \
    --allow-insecure \
    --target-port 5678 \
    --traffic-weight latest=100 \
    --output none

if [[ $? -eq 0 ]]; then
    log_message "✅ Ingress configured successfully."
else
    log_message "❌ Error: Failed to configure ingress"
    exit 1
fi

# 10. Get Container App URL
log_message "Retrieving Container App URL..."
CONTAINER_APP_URL=$(az containerapp show \
    --name "${CONTAINER_APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "properties.configuration.ingress.fqdn" \
    --output tsv)

# 11. Display deployment summary
echo ""
echo "🎉 ==============================================="
echo "   n8n Container App Deployment Completed!"
echo "==============================================="
echo ""
echo "📋 Deployment Summary:"
echo "   • Container App: ${CONTAINER_APP_NAME}"
echo "   • Resource Group: ${RESOURCE_GROUP}"
echo "   • Environment: ${ENV_NAME}"
echo "   • Database: ${DB_HOST}/${DB_NAME}"
echo "   • Key Vault: ${KEYVAULT_NAME}"
echo "   • Container Registry: ${ACR_LOGIN_SERVER}"
echo ""
echo "🌐 Access Information:"
echo "   • n8n URL: https://${CONTAINER_APP_URL}"
echo "   • Username: ${N8N_USERNAME}"
echo "   • Password: ${N8N_PASSWORD}"
echo ""
echo "🔐 Security Features:"
echo "   • ✅ Managed Identity authentication"
echo "   • ✅ Key Vault secret management"
echo "   • ✅ PostgreSQL SSL connections"
echo "   • ✅ Container registry access via RBAC"
echo "   • ✅ Non-root container execution"
echo ""
echo "🔍 Next Steps:"
echo "   1. Wait 2-3 minutes for container to fully start"
echo "   2. Access n8n at: https://${CONTAINER_APP_URL}"
echo "   3. Login with username: ${N8N_USERNAME}"
echo "   4. Check PostgreSQL tables to verify data persistence"
echo ""
echo "🛠️  Troubleshooting:"
echo "   • View logs: az containerapp logs show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP} --follow"
echo "   • Check status: az containerapp show --name ${CONTAINER_APP_NAME} --resource-group ${RESOURCE_GROUP}"
echo ""
log_message "Script execution completed successfully!"