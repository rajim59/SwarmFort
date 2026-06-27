#!/bin/bash
set -e

SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')

if [ "$SWARM_STATE" = "active" ]; then
    echo "Swarm is already active on this node. Skipping initialization."
    exit 0
fi

if docker swarm init > /dev/null 2>&1; then
    echo "Swarm initialized successfully using default routing."
    exit 0
fi

OS_IP=$(hostname -I | awk '{print $1}')
if docker swarm init --advertise-addr "$OS_IP" > /dev/null 2>&1; then
    echo "Swarm initialized successfully using OS IP: $OS_IP"
    exit 0
fi

DAEMON_IP=$(docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}')
docker swarm init --advertise-addr "$DAEMON_IP" > /dev/null 2>&1
echo "Swarm initialized successfully using Daemon IP: $DAEMON_IP"