#!/bin/bash

set -e

readonly NODE_EXPORTER_VERSION="1.3.1"
readonly NODE_EXPORTER_USER="node_exporter"
readonly NODE_EXPORTER_DIR="/opt/node_exporter"
readonly NODE_EXPORTER_BIN="/usr/local/bin/node_exporter"
readonly NODE_EXPORTER_SERVICE="/etc/systemd/system/node_exporter.service"
readonly ARCHIVE_NAME="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
readonly EXTRACTED_DIR="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"

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
    useradd --no-create-home --shell /bin/false "$NODE_EXPORTER_USER"
fi

# Install Node Exporter binary if not already present
if [ -x "$NODE_EXPORTER_BIN" ]; then
    echo "Node Exporter is already installed. Skipping installation."
else
    wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${ARCHIVE_NAME}"
    tar -xzf "$ARCHIVE_NAME"
    cp "${EXTRACTED_DIR}/node_exporter" "$NODE_EXPORTER_BIN"
    chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$NODE_EXPORTER_BIN"

    # Clean up
    rm -rf "$ARCHIVE_NAME" "$EXTRACTED_DIR"
fi

# Set up systemd service if not already created
if [ -f "$NODE_EXPORTER_SERVICE" ]; then
    echo "Node Exporter service file already exists. Skipping service creation."
else
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

    chmod 644 "$NODE_EXPORTER_SERVICE"
    systemctl daemon-reload
    systemctl start node_exporter
    systemctl enable node_exporter

    echo "Node Exporter v$NODE_EXPORTER_VERSION has been installed and started."
fi
