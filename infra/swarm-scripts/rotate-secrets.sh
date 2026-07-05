#!/bin/bash
set -euo pipefail

# ============================================================
# SwarmFort - Production Zero-Downtime Secret Rotation (Req 46)
# ============================================================

TIMESTAMP=$(date +%s)
NEW_DB_PASS=$(openssl rand -base64 16)
NEW_API_KEY=$(openssl rand -base64 32)

echo "Initiating Secure Secret Rotation..."

# Step 1: Create Versioned Secrets (Prevents In-Use Conflict)
echo "$NEW_DB_PASS" | docker secret create "db_password_${TIMESTAMP}" -
echo "$NEW_API_KEY" | docker secret create "api_key_${TIMESTAMP}" -

# Step 2: Roll out services with new versioned secrets
echo "Rolling out services with updated secrets..."
docker service update --secret-add "source=db_password_${TIMESTAMP},target=db_password" swarmfort_db
docker service update --secret-add "source=api_key_${TIMESTAMP},target=api_key" swarmfort_api
docker service update --secret-add "source=api_key_${TIMESTAMP},target=api_key" swarmfort_redis

echo "✅ Secret rotation deployed. Note: Old secret versions can be pruned after tasks stabilize."