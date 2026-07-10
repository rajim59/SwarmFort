#!/bin/bash
set -euo pipefail

CRON_SCRIPT_PATH="/home/azureuser/swarm-scripts/cleanup-disk.sh"

# Grant execute permission to the cleanup script
chmod +x "$CRON_SCRIPT_PATH"

# Schedule the cleanup script to run daily at 2:00 AM
CRONJOB="0 2 * * * $CRON_SCRIPT_PATH >> /var/log/cleanup.log 2>&1"

# Register the cron job while retaining existing cron entries
(crontab -l 2>/dev/null || true; echo "$CRONJOB") | crontab -

echo "✅ Nightly cleanup cron job successfully installed at 2:00 AM."