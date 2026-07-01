#!/bin/bash
set -e

TOKEN="$1"
MANAGER_IP="$2"

if [ -z "$TOKEN" ] || [ -z "$MANAGER_IP" ]; then
    echo "Usage: $0 <worker-token> <manager-private-ip>"
    exit 1
fi

SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')

if [ "$SWARM_STATE" = "active" ]; then
    echo "Node is already part of a Swarm cluster."
else
    docker swarm join --token "$TOKEN" "$MANAGER_IP:2377"
    echo "Node joined the swarm successfully."
fi