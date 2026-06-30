#!/bin/bash
set -e

# Get primary private IP (assuming one NIC, one subnet)
PRIVATE_IP=$(hostname -I | awk '{print $1}')
echo "Advertising Swarm on IP: $PRIVATE_IP"

docker swarm init --advertise-addr "$PRIVATE_IP"

# Create overlay network (if needed later)
docker network create --driver overlay --attachable swarm-net || true

# Output tokens
echo "========================================"
echo "Worker join command:"
docker swarm join-token worker | grep "docker swarm join"
echo "Manager join command:"
docker swarm join-token manager | grep "docker swarm join"
echo "========================================"