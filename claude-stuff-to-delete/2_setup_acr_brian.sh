#!/bin/bash
# Setup Azure Container Registry for Brian's n8n deployment
# Using standard n8n image (not custom build) for faster deployment

echo "[$(date)] Starting ACR setup for Brian's n8n deployment..."

# Configuration Variables - CUSTOMIZED FOR BRIAN'S SETUP
RESOURCE_GROUP="rg-nonprofit-ai"                    # Brian's existing resource group
LOCATION="canadacentral"                            # Brian's region  
ACR_NAME="briannonprofitacr"                        # Globally unique ACR name
IMAGE_NAME="n8n"                                    # Using standard n8n image
STANDARD_N8N_IMAGE="n8nio/n8n:latest"              # Official n8n Docker image

# Validate required variables
echo "[$(date)] Validating required variables..."
[[ -z "${RESOURCE_GROUP}" ]] && { echo "Error: RESOURCE_GROUP is not set"; exit 1; }
[[ -z "${LOCATION}" ]] && { echo "Error: LOCATION is not set"; exit 1; }
[[ -z "${ACR_NAME}" ]] && { echo "Error: ACR_NAME is not set"; exit 1; }
[[ -z "${IMAGE_NAME}" ]] && { echo "Error: IMAGE_NAME is not set"; exit 1; }
echo "[$(date)] Variable validation completed."

# Function for timestamped logging
log_message() {
    echo "[$(date)] $1"
}

# Function to check if a resource exists
check_resource_exists() {
    local resource_type=$1
    local resource_name=$2
    
    case $resource_type in
        "acr")
            az acr show --name "${resource_name}" --output none 2>/dev/null
            ;;
        *)
            echo "Unknown resource type: ${resource_type}"
            return 1
            ;;
    esac
}

# Function to validate Azure Container Registry naming
validate_acr_name() {
    local name=$1
    
    # ACR names: 5-50 chars, alphanumeric only, globally unique
    if [[ ! "$name" =~ ^[a-zA-Z0-9]{5,50}$ ]]; then
        echo "❌ Invalid ACR name: '$name'"
        echo "   Must be 5-50 characters, alphanumeric only (no hyphens or special characters)"
        return 1
    fi
    return 0
}

# 1. Validate ACR name
log_message "Validating ACR name '${ACR_NAME}'..."
validate_acr_name "${ACR_NAME}" || exit 1
log_message "✅ ACR name validation passed."

# 2. Create Azure Container Registry if it doesn't exist
log_message "Checking if ACR '${ACR_NAME}' exists..."
if check_resource_exists "acr" "${ACR_NAME}"; then
    log_message "✅ ACR '${ACR_NAME}' already exists. Skipping creation."
    
    # Verify ACR location matches our setup
    ACR_LOCATION=$(az acr show --name "${ACR_NAME}" --query "location" --output tsv)
    log_message "Existing ACR location: ${ACR_LOCATION}"
    
    if [[ "${ACR_LOCATION}" != "${LOCATION}" ]]; then
        log_message "⚠️  Warning: ACR location (${ACR_LOCATION}) differs from target location (${LOCATION})"
        log_message "This may increase data transfer costs but will still work."
    fi
else
    log_message "Creating Azure Container Registry '${ACR_NAME}'..."
    
    # Create ACR with Basic tier (cost-effective for development)
    az acr create \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${ACR_NAME}" \
        --location "${LOCATION}" \
        --sku Basic \
        --admin-enabled false \
        --output none
    
    if [[ $? -eq 0 ]]; then
        log_message "✅ ACR created successfully."
        log_message "Configuration:"
        log_message "  • Name: ${ACR_NAME}"
        log_message "  • SKU: Basic (cost-optimized)"
        log_message "  • Admin User: Disabled (using managed identity)"
        log_message "  • Location: ${LOCATION}"
    else
        log_message "❌ Error: Failed to create ACR"
        
        # Check if name conflict
        log_message "💡 If this is a naming conflict, try a more unique ACR name:"
        TIMESTAMP=$(date +%Y%m%d%H%M)
        echo "   • brian${TIMESTAMP}acr"
        echo "   • nonprofitai${TIMESTAMP}acr"  
        echo "   • ${ACR_NAME}${TIMESTAMP}"
        echo ""
        echo "Update the ACR_NAME variable in this script and retry."
        exit 1
    fi
fi

# 3. Get ACR login server
log_message "Getting ACR login server..."
ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query "loginServer" --output tsv)
log_message "ACR Login Server: ${ACR_LOGIN_SERVER}"

# 4. Import standard n8n image to ACR (instead of building custom image)
log_message "Importing standard n8n image to ACR..."
log_message "Source: ${STANDARD_N8N_IMAGE}"
log_message "Target: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest"

# Import the official n8n image to our ACR
az acr import \
    --name "${ACR_NAME}" \
    --source "${STANDARD_N8N_IMAGE}" \
    --image "${IMAGE_NAME}:latest" \
    --output none

if [[ $? -eq 0 ]]; then
    log_message "✅ n8n image imported successfully to ACR."
    
    # Verify the image was imported
    log_message "Verifying imported image..."
    IMPORTED_IMAGE=$(az acr repository show \
        --name "${ACR_NAME}" \
        --repository "${IMAGE_NAME}" \
        --query "name" \
        --output tsv 2>/dev/null)
    
    if [[ -n "${IMPORTED_IMAGE}" ]]; then
        log_message "✅ Image verification successful: ${IMPORTED_IMAGE}"
        
        # Get image details
        IMAGE_TAGS=$(az acr repository show-tags \
            --name "${ACR_NAME}" \
            --repository "${IMAGE_NAME}" \
            --output tsv)
        log_message "Available tags: ${IMAGE_TAGS}"
    else
        log_message "❌ Error: Image verification failed"
        exit 1
    fi
else
    log_message "❌ Error: Failed to import n8n image to ACR"
    log_message "This could be due to:"
    log_message "  • Network connectivity issues"
    log_message "  • Docker Hub rate limits"
    log_message "  • ACR permissions"
    exit 1
fi

# 5. Display ACR information
log_message "Getting ACR resource information..."
ACR_ID=$(az acr show --name "${ACR_NAME}" --query "id" --output tsv)
ACR_SKU=$(az acr show --name "${ACR_NAME}" --query "sku.name" --output tsv)

# 6. Display summary
echo ""
echo "🎉 ==============================================="
echo "   Azure Container Registry Setup Complete!"
echo "==============================================="
echo ""
echo "📋 ACR Summary:"
echo "   • Registry Name: ${ACR_NAME}"
echo "   • Login Server: ${ACR_LOGIN_SERVER}"
echo "   • Location: ${LOCATION}"
echo "   • SKU: ${ACR_SKU}"
echo "   • Resource ID: ${ACR_ID}"
echo ""
echo "🐳 Image Information:"
echo "   • Repository: ${IMAGE_NAME}"
echo "   • Tag: latest"
echo "   • Source: ${STANDARD_N8N_IMAGE}"
echo "   • Full Image Path: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest"
echo ""
echo "🔧 Configuration for Next Script:"
echo "   • ACR_NAME=${ACR_NAME}"
echo "   • ACR_LOGIN_SERVER=${ACR_LOGIN_SERVER}"
echo "   • IMAGE_NAME=${IMAGE_NAME}"
echo ""
echo "🔄 Next Steps:"
echo "   1. Run script 3_deploy_n8n_brian.sh to deploy n8n Container App"
echo "   2. The script will use the image: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:latest"
echo ""
log_message "Script execution completed successfully!"