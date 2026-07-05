#!/bin/bash
set -euo pipefail

echo "Executing production disk space optimization..."
docker system prune -af --filter "until=72h"
docker volume prune -f
echo "✅ Nightly disk cleanup completed successfully."