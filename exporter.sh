#!/bin/bash

set -e

NODE_EXPORTER_VERSION="1.3.1"
NODE_EXPORTER_USER="node_exporter"
NODE_EXPORTER_DIR="/opt/node_exporter"
NODE_EXPORTER_BIN="/usr/local/bin/node_exporter"
NODE_EXPORTER_SERVICE="/etc/systemd/system/node_exporter.service"

# Function to check if a user exists
user_exists() {
    id "$1" &>/dev/null
}

# Update system packages
apt update -y

# Install dependencies
apt install -y wget

# Check if the node_exporter user exists
if user_exists "$NODE_EXPORTER_USER"; then
    echo "User '$NODE_EXPORTER_USER' already exists. Skipping user creation."
else
    # Create system user for Node Exporter
    useradd --no-create-home --shell /bin/false "$NODE_EXPORTER_USER"
fi

# Download and install Node Exporter if not installed already
if [ -x "$NODE_EXPORTER_BIN" ]; then
    echo "Node Exporter is already installed. Skipping installation."
else
    # Download and install Node Exporter
    wget "https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz"
    tar xvf "node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz"
    mv "node_exporter-$NODE_EXPORTER_VERSION.linux-amd64" "$NODE_EXPORTER_DIR"
    cp "$NODE_EXPORTER_DIR/node_exporter" "$NODE_EXPORTER_BIN"
    chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$NODE_EXPORTER_BIN"
fi

# Create systemd service for Node Exporter if not created already
if [ -f "$NODE_EXPORTER_SERVICE" ]; then
    echo "Node Exporter service file already exists. Skipping service creation."
else
    # Create systemd service for Node Exporter
    cat > "$NODE_EXPORTER_SERVICE" << EOL
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
ExecStart=$NODE_EXPORTER_BIN

[Install]
WantedBy=multi-user.target
EOL

    # Set permissions for the service unit file
    chmod 644 "$NODE_EXPORTER_SERVICE"

    # Reload systemd daemon and start Node Exporter
    systemctl daemon-reload
    systemctl start node_exporter
    systemctl enable node_exporter

    echo "Node Exporter v$NODE_EXPORTER_VERSION has been installed and started."
fi
