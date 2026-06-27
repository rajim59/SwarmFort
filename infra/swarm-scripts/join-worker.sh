#!/bin/bash
set -e

SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}')

if [ "$SWARM_STATE" != "active" ]; then
    echo "Error: This node is not part of an active swarm."
    exit 1
fi

MANAGER_IP=$(docker info --format '{{.Swarm.NodeAddr}}')
MGR_TOKEN=$(docker swarm join-token -q manager)
WKR_TOKEN=$(docker swarm join-token -q worker)

echo "Manager Join Command:"
echo "docker swarm join --token ${MGR_TOKEN} ${MANAGER_IP}:2377"
echo ""
echo "Worker Join Command:"
echo "docker swarm join --token ${WKR_TOKEN} ${MANAGER_IP}:2377"