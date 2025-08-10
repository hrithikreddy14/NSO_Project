#!/bin/bash

set -e

# Check if running with root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Step 1: Update system packages
apt-get update -y

# Check and install dependencies
if ! command -v wget >/dev/null; then
    apt-get install wget -y
fi

if ! command -v tar >/dev/null; then
    apt-get install tar -y
fi

# Step 2: Create Prometheus user
if ! id "prometheus" &>/dev/null; then
    useradd --no-create-home --shell /bin/false prometheus
fi

# Step 3: Create necessary directories
PROMETHEUS_DIR="/opt/prometheus"
mkdir -p /etc/prometheus
mkdir -p ${PROMETHEUS_DIR}
mkdir -p /var/lib/prometheus

# Step 4: Download and extract Prometheus
PROMETHEUS_VERSION="2.26.0"
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz -C ${PROMETHEUS_DIR} --strip-components=1

# Step 5: Set ownership and permissions
chown -R prometheus:prometheus ${PROMETHEUS_DIR}
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
chmod -R 755 /var/lib/prometheus

# Step 6: Create Prometheus service file
PROMETHEUS_BIN="/usr/local/bin/prometheus"
PROMETHEUS_SERVICE="/etc/systemd/system/prometheus.service"

cat > ${PROMETHEUS_SERVICE} << EOL
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=${PROMETHEUS_BIN} \
        --config.file /etc/prometheus/prometheus.yml \
        --storage.tsdb.path /var/lib/prometheus/ \
        --web.console.templates=/etc/prometheus/consoles \
        --web.console.libraries=/etc/prometheus/console_libraries \
        --web.listen-address=0.0.0.0:9090
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOL

# Step 7: Reload systemd and start Prometheus
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

echo "Prometheus installation completed."

# Step 8: Install Node Exporter
NODE_EXPORTER_VERSION="1.3.1"
NODE_EXPORTER_BIN="/usr/local/bin/node_exporter"
NODE_EXPORTER_SERVICE="/etc/systemd/system/node_exporter.service"

wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter ${NODE_EXPORTER_BIN}
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

# Step 9: Create Node Exporter service file
cat > ${NODE_EXPORTER_SERVICE} << EOL
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=${NODE_EXPORTER_BIN}

[Install]
WantedBy=multi-user.target
EOL

# Step 10: Reload systemd and start Node Exporter
systemctl daemon-reload
systemctl start node_exporter

echo "Node Exporter installation completed."

echo "Script execution completed."
