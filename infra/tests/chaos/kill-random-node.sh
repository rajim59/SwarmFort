#!/bin/bash
set -euo pipefail

# ============================================================
# Chaos Test: Random Worker Node Kill
# Verify Swarm self-healing by draining and reactivating a worker node
# ============================================================

echo "=== Chaos Test: Random Node Kill ==="

# Identify worker nodes only (exclude manager nodes)
WORKER_NODES=$(docker node ls --format '{{.Hostname}} {{.Role}}' | grep 'worker' | awk '{print $1}')

if [ -z "$WORKER_NODES" ]; then
    echo "ERROR: No worker nodes found in the cluster."
    exit 1
fi

# Select a random worker node
TARGET_NODE=$(echo "$WORKER_NODES" | shuf -n 1)
echo "Target worker node: $TARGET_NODE"

# Drain the selected node
echo "Draining node $TARGET_NODE..."
docker node update --availability drain "$TARGET_NODE"

# Wait for Swarm to reschedule tasks
echo "Waiting 30 seconds for Swarm to reschedule services..."
sleep 30

# Verify service health after rescheduling
echo "Checking service status after drain..."
SERVICES=$(docker service ls --format '{{.Name}}')
ALL_HEALTHY=true

for svc in $SERVICES; do
    REPLICAS=$(docker service inspect "$svc" --format '{{.Spec.Mode.Replicated.Replicas}}')
    RUNNING=$(docker service ps "$svc" --format '{{.CurrentState}}' | grep -c 'Running' || true)

    if [ "$RUNNING" -ge "$REPLICAS" ]; then
        echo "  ✓ $svc: $RUNNING/$REPLICAS running"
    else
        echo "  ✗ $svc: $RUNNING/$REPLICAS running (EXPECTED: $REPLICAS)"
        ALL_HEALTHY=false
    fi
done

# Reactivate the drained node
echo "Reactivating node $TARGET_NODE..."
docker node update --availability active "$TARGET_NODE"

# Allow time for the node to rejoin the cluster
echo "Waiting 15 seconds for node to rejoin..."
sleep 15

# Final validation
if [ "$ALL_HEALTHY" = true ]; then
    echo "=== PASS: All services rescheduled successfully. Swarm self-healing verified. ==="
    exit 0
else
    echo "=== FAIL: Some services did not reschedule properly. ==="
    exit 1
fi