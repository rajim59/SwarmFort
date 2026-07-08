#!/bin/bash
set -euo pipefail


# Docker events stream → Loki (HTTP API)


LOKI_URL="${LOKI_URL:-http://loki:3100/loki/api/v1/push}"

echo "Starting Docker event exporter to $LOKI_URL"

while true; do
  docker events --format '{{json .}}' | while read -r event; do
    TIMESTAMP=$(date +%s%N)
    curl -s -X POST "$LOKI_URL" \
      -H "Content-Type: application/json" \
      --data-raw "$(cat <<EOF
{
  "streams": [
    {
      "stream": { "job": "docker-events" },
      "values": [ ["$TIMESTAMP", "$event"] ]
    }
  ]
}
EOF
)" > /dev/null 2>&1 || echo "Failed to send event" >&2
  done
  sleep 5   
done