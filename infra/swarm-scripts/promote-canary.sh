#!/bin/bash
set -euo pipefail

# ============================================================
# SwarmFort - Advanced Canary Promotion Engine (Req 40)
# ============================================================

SERVICE="${1:-swarmfort_api}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
ERROR_THRESHOLD="0.05" # Max 5% failure allowed

echo "Evaluating Canary Deployment Metrics for $SERVICE..."
sleep 15 # Wait for metrics aggregation

# Query Error Rate from Prometheus
PROMETHEUS_RESPONSE=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=sum(rate(http_requests_total{status=~\"5..\"}[2m])) / sum(rate(http_requests_total[2m]))")

# Parse JSON gracefully
ERROR_RATE=$(echo "$PROMETHEUS_RESPONSE" | jq -r '.data.result[0].value[1] // 0')

if [ "$ERROR_RATE" = "NaN" ] || [ "$ERROR_RATE" = "null" ]; then
    ERROR_RATE=0
fi

echo "Current Canary Error Rate: $ERROR_RATE"

# Evaluation logic using awk
if awk -v err="$ERROR_RATE" -v thresh="$ERROR_THRESHOLD" 'BEGIN { exit (err > thresh) ? 0 : 1 }'; then
    echo "❌ CRITICAL: Canary error rate exceeds threshold! Initiating automated rollback..."
    docker service rollback "$SERVICE"
    exit 1
else
    echo "✅ SUCCESS: Canary health metrics verified. Continuous delivery stable."
fi