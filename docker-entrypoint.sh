#!/bin/bash
set -e

# Install community nodes into n8n's expected location on startup
# This is needed because /data is a volume that's empty at container start
NODES_DIR="/data/.n8n/nodes"

if [ ! -d "$NODES_DIR/node_modules/@ixiam/n8n-nodes-civicrm" ] || \
   [ ! -d "$NODES_DIR/node_modules/@tavily/n8n-nodes-tavily" ] || \
   [ ! -d "$NODES_DIR/node_modules/n8n-nodes-mcp" ]; then
    echo "Installing community nodes..."
    mkdir -p "$NODES_DIR"
    cd "$NODES_DIR"
    npm init -y 2>/dev/null || true
    npm install \
        @ixiam/n8n-nodes-civicrm@1.1.41 \
        @tavily/n8n-nodes-tavily@0.5.1 \
        n8n-nodes-mcp@0.1.37 \
        --bin-links=false \
        --package-lock=false
    echo "Community nodes installed successfully."
else
    echo "Community nodes already installed."
fi

# Start n8n
exec n8n start
