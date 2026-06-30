#!/bin/bash
set -e

# Usage: join-worker.sh <worker-token> <manager-private-ip>
TOKEN="$1"
MANAGER_IP="$2"

if [ -z "$TOKEN" ] || [ -z "$MANAGER_IP" ]; then
    echo "Usage: $0 <worker-token> <manager-private-ip>"
    exit 1
fi

# Join as worker
docker swarm join --token "$TOKEN" "$MANAGER_IP:2377"

echo "Node joined the swarm successfully."