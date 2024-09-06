#!/bin/bash

# Author: Ravi Shankar Rajupalepu
# Date: 2024-09-06
# This script installs the Loki Docker plugin, updates Docker's log driver to Loki,
# and restarts Docker while preserving the state of running containers.

# Path to your .env file
ENV_FILE=".env"

# Source the .env file to get the Loki URL
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "Environment file .env not found!"
  exit 1
fi

# Validate the required environment variable
if [ -z "$LOKI_URL" ]; then
  echo "LOKI_URL is not set in the .env file!"
  exit 1
fi

# Install the Loki Docker plugin
echo "Installing Loki Docker plugin..."
docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions

# Update Docker daemon configuration
DAEMON_JSON="/etc/docker/daemon.json"
echo "Updating Docker daemon configuration..."
sudo tee "$DAEMON_JSON" > /dev/null <<EOL
{
    "debug": true,
    "log-driver": "loki",
    "log-opts": {
        "loki-url": "$LOKI_URL",
        "loki-batch-size": "400"
    }
}
EOL

# Define a temporary file to store container names
TEMP_FILE=$(mktemp)

# Get the names of all running containers and store them in the temp file
docker ps --format '{{.Names}}' > "$TEMP_FILE"

# Restart Docker service
echo "Restarting Docker service..."
sudo systemctl restart docker

# Wait a few seconds for Docker to restart
sleep 10

# Read the temporary file and start containers that were stopped
while IFS= read -r container_name; do
  echo "Starting container $container_name..."
  docker start "$container_name"
done < "$TEMP_FILE"

# Remove the temporary file
rm -f "$TEMP_FILE"

echo "Docker service restarted and containers restored."
