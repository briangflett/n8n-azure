#!/bin/bash
set -e

# Install community nodes into n8n's expected location on startup
# This is needed because /data is a volume that's empty at container start
NODES_DIR="/data/.n8n/nodes"

if [ ! -d "$NODES_DIR/node_modules/@ixiam/n8n-nodes-civicrm" ] || \
   [ ! -d "$NODES_DIR/node_modules/@tavily/n8n-nodes-tavily" ] || \
   [ ! -d "$NODES_DIR/node_modules/n8n-nodes-mcp" ] || \
   [ ! -d "$NODES_DIR/node_modules/@cryptodevops/n8n-nodes-youtube-transcript" ]; then
    echo "Installing community nodes..."
    mkdir -p "$NODES_DIR"
    cd "$NODES_DIR"
    npm init -y 2>/dev/null || true
    npm install \
        @ixiam/n8n-nodes-civicrm@1.1.41 \
        @tavily/n8n-nodes-tavily@0.5.1 \
        n8n-nodes-mcp@0.1.37 \
        @cryptodevops/n8n-nodes-youtube-transcript@1.7.4 \
        --bin-links=false \
        --package-lock=false \
        --ignore-scripts
    # Remove isolated-vm from community nodes - its native addon
    # is incompatible with Node.js 24 and crashes n8n on startup.
    # n8n has its own isolated-vm bundled with the main package.
    rm -rf "$NODES_DIR/node_modules/isolated-vm"
    echo "Community nodes installed successfully."
else
    # Also clean up isolated-vm from any previous installs
    rm -rf "$NODES_DIR/node_modules/isolated-vm"
    echo "Community nodes already installed."
fi

# Start n8n
exec n8n start
