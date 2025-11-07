#!/bin/bash
# Setup Container Apps Environment for Brian's n8n deployment
# Adapted from Ori Ziv's guide for existing Azure resources

echo "[$(date)] Starting Container Apps Environment setup for Brian's n8n deployment..."

# Configuration Variables - CUSTOMIZED FOR BRIAN'S SETUP
RESOURCE_GROUP="rg-nonprofit-ai"                    # Brian's existing resource group
LOCATION="canadacentral"                            # Brian's region
WORKLOAD_PROFILE_NAME="n8n-workload-profile"       # Workload profile for scaling
ENV_NAME="n8n-env"                                 # Container Apps Environment name

# Validate required variables
echo "[$(date)] Validating required variables..."
[[ -z "${RESOURCE_GROUP}" ]] && { echo "Error: RESOURCE_GROUP is not set"; exit 1; }
[[ -z "${LOCATION}" ]] && { echo "Error: LOCATION is not set"; exit 1; }
[[ -z "${WORKLOAD_PROFILE_NAME}" ]] && { echo "Error: WORKLOAD_PROFILE_NAME is not set"; exit 1; }
[[ -z "${ENV_NAME}" ]] && { echo "Error: ENV_NAME is not set"; exit 1; }
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
        "resource-group")
            az group show --name "${resource_name}" --output none 2>/dev/null
            ;;
        "containerapp-env")
            az containerapp env show --name "${resource_name}" --resource-group "${resource_group}" --output none 2>/dev/null
            ;;
        *)
            echo "Unknown resource type: ${resource_type}"
            return 1
            ;;
    esac
}

# 1. Verify existing resource group
log_message "Verifying existing resource group '${RESOURCE_GROUP}'..."
if check_resource_exists "resource-group" "${RESOURCE_GROUP}" ""; then
    log_message "✅ Resource group '${RESOURCE_GROUP}' exists."
else
    log_message "❌ Error: Resource group '${RESOURCE_GROUP}' does not exist!"
    log_message "💡 Please verify the resource group name or create it first."
    exit 1
fi

# 2. Install Container Apps extension if needed
log_message "Installing/updating Azure Container Apps extension..."
az extension add --name containerapp --upgrade --only-show-errors

if [[ $? -eq 0 ]]; then
    log_message "✅ Container Apps extension installed/updated successfully."
else
    log_message "❌ Error: Failed to install Container Apps extension"
    exit 1
fi

# 3. Register required providers
log_message "Registering required Azure providers..."
az provider register --namespace Microsoft.App --only-show-errors
az provider register --namespace Microsoft.OperationalInsights --only-show-errors

# Wait for provider registration
log_message "Waiting for provider registration to complete..."
sleep 30

# Check provider registration status
APP_PROVIDER_STATUS=$(az provider show --namespace Microsoft.App --query "registrationState" --output tsv)
INSIGHTS_PROVIDER_STATUS=$(az provider show --namespace Microsoft.OperationalInsights --query "registrationState" --output tsv)

log_message "Provider Status:"
log_message "  • Microsoft.App: ${APP_PROVIDER_STATUS}"
log_message "  • Microsoft.OperationalInsights: ${INSIGHTS_PROVIDER_STATUS}"

# 4. Create Container App Environment if it doesn't exist
log_message "Checking if Container App Environment '${ENV_NAME}' exists..."
if check_resource_exists "containerapp-env" "${ENV_NAME}" "${RESOURCE_GROUP}"; then
    log_message "✅ Container App Environment '${ENV_NAME}' already exists. Skipping creation."
else
    log_message "Creating Container App Environment '${ENV_NAME}'..."
    
    # Create Log Analytics workspace first (required for Container Apps)
    WORKSPACE_NAME="${ENV_NAME}-logs"
    log_message "Creating Log Analytics workspace '${WORKSPACE_NAME}'..."
    
    az monitor log-analytics workspace create \
        --resource-group "${RESOURCE_GROUP}" \
        --workspace-name "${WORKSPACE_NAME}" \
        --location "${LOCATION}" \
        --sku PerGB2018 \
        --output none
    
    if [[ $? -eq 0 ]]; then
        log_message "✅ Log Analytics workspace created successfully."
        
        # Get workspace ID and key
        WORKSPACE_ID=$(az monitor log-analytics workspace show \
            --resource-group "${RESOURCE_GROUP}" \
            --workspace-name "${WORKSPACE_NAME}" \
            --query "customerId" \
            --output tsv)
        
        WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
            --resource-group "${RESOURCE_GROUP}" \
            --workspace-name "${WORKSPACE_NAME}" \
            --query "primarySharedKey" \
            --output tsv)
        
        log_message "Log Analytics workspace details:"
        log_message "  • Workspace ID: ${WORKSPACE_ID}"
        log_message "  • Workspace Key: [REDACTED]"
        
        # Create Container App Environment
        log_message "Creating Container App Environment with consumption workload profile..."
        az containerapp env create \
            --name "${ENV_NAME}" \
            --resource-group "${RESOURCE_GROUP}" \
            --location "${LOCATION}" \
            --logs-workspace-id "${WORKSPACE_ID}" \
            --logs-workspace-key "${WORKSPACE_KEY}" \
            --output none
        
        if [[ $? -eq 0 ]]; then
            log_message "✅ Container App Environment created successfully."
            
            # Create consumption workload profile
            log_message "Creating consumption workload profile '${WORKLOAD_PROFILE_NAME}'..."
            az containerapp env workload-profile set \
                --name "${ENV_NAME}" \
                --resource-group "${RESOURCE_GROUP}" \
                --workload-profile-name "${WORKLOAD_PROFILE_NAME}" \
                --workload-profile-type "Consumption" \
                --min-nodes 0 \
                --max-nodes 10 \
                --output none
            
            if [[ $? -eq 0 ]]; then
                log_message "✅ Workload profile created successfully."
                log_message "Configuration:"
                log_message "  • Profile Name: ${WORKLOAD_PROFILE_NAME}"
                log_message "  • Type: Consumption (pay-per-use)"
                log_message "  • Min Nodes: 0 (scales to zero)"
                log_message "  • Max Nodes: 10 (auto-scaling limit)"
            else
                log_message "⚠️  Workload profile creation failed, but environment exists."
                log_message "This may be normal for some regions. Continuing..."
            fi
        else
            log_message "❌ Error: Failed to create Container App Environment"
            exit 1
        fi
    else
        log_message "❌ Error: Failed to create Log Analytics workspace"
        exit 1
    fi
fi

# 5. Verify setup
log_message "Verifying Container App Environment setup..."
ENV_STATUS=$(az containerapp env show \
    --name "${ENV_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query "properties.provisioningState" \
    --output tsv)

log_message "Environment Status: ${ENV_STATUS}"

if [[ "${ENV_STATUS}" == "Succeeded" ]]; then
    log_message "✅ Container App Environment is ready for n8n deployment."
else
    log_message "⚠️  Environment status: ${ENV_STATUS}"
    log_message "This may still be provisioning. Check status before proceeding to next step."
fi

# 6. Display summary
echo ""
echo "🎉 ==============================================="
echo "   Container Apps Environment Setup Complete!"
echo "==============================================="
echo ""
echo "📋 Setup Summary:"
echo "   • Resource Group: ${RESOURCE_GROUP}"
echo "   • Location: ${LOCATION}"
echo "   • Environment Name: ${ENV_NAME}"
echo "   • Workload Profile: ${WORKLOAD_PROFILE_NAME}"
echo "   • Status: ${ENV_STATUS}"
echo ""
echo "🔄 Next Steps:"
echo "   1. Run script 2_setup_acr_brian.sh to create Container Registry"
echo "   2. Run script 3_deploy_n8n_brian.sh to deploy n8n"
echo ""
log_message "Script execution completed successfully!"