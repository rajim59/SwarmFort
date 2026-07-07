#!/bin/bash
set -euo pipefail
STACK_FILE="${1:-infra/docker/docker-stack.yml}"
docker stack deploy -c "$STACK_FILE" swarmfort