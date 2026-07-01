#!/bin/bash
set -e

SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')

if [ "$SWARM_STATE" = "active" ]; then
    echo "Swarm is already initialized on this node."
else
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    echo "Advertising Swarm on IP: $PRIVATE_IP"
    docker swarm init --advertise-addr "$PRIVATE_IP"
fi


if ! docker network ls | grep -q "swarm-net"; then
    echo "Creating encrypted overlay network..."
    docker network create --opt encrypted --driver overlay --attachable swarm-net
fi