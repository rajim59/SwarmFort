#!/bin/bash
set -euo pipefail
SERVICE="${1:-swarmfort_api}"
docker service update \
  --update-parallelism 1 \
  --update-delay 10s \
  --update-failure-action rollback \
  "$SERVICE"