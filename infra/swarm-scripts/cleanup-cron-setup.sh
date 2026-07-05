#!/bin/bash
set -euo pipefail

CRON_SCRIPT_PATH="/home/azureuser/swarm-scripts/cleanup-disk.sh"

# স্ক্রিপ্ট এক্সিকিউটেবল পারমিশন নিশ্চিত করা
chmod +x "$CRON_SCRIPT_PATH"

CRONJOB="0 2 * * * $CRON_SCRIPT_PATH >> /var/log/cleanup.log 2>&1"

(crontab -l 2>/dev/null || true; echo "$CRONJOB") | crontab -
echo "✅ Nightly cleanup cron job successfully installed at 2:00 AM."