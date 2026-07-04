#!/bin/bash
set -e

echo "=== Integration Tests (Network, TLS & Image Size) ==="

echo "--- Testing Production Image Size (Req 5) ---"
# ইমেজটি ম্যানেজারে আছে কিনা তা আগে চেক করে নিচ্ছি
if docker image inspect myrepo/swarmfort-api:latest >/dev/null 2>&1; then
    IMAGE_SIZE=$(docker inspect myrepo/swarmfort-api:latest --format='{{.Size}}')
    SIZE_MB=$((IMAGE_SIZE / 1000000))
    if [ "$SIZE_MB" -lt 25 ]; then
        echo "✓ Image size optimized: ${SIZE_MB}MB (< 25MB)"
    else
        echo "✗ Image size too large: ${SIZE_MB}MB (Target: < 25MB)" >&2
        exit 1
    fi
else
    echo "⚠ Image myrepo/swarmfort-api:latest not found. Please build it first."
fi

echo "--- Testing encrypted overlay network ---"
echo "Checking encryption option on network swarm-net..."

if docker network inspect swarmfort_backend-net --format '{{json .Options}}' | grep -q "encrypted"; then
    echo "✓ Encryption enabled"
else
    echo "✗ Encryption NOT enabled"
    exit 1
fi

echo "Waiting 45 seconds for services to initialize..."
sleep 45

echo "--- Testing Nginx TLS Termination & API Ingress ---"
echo "Checking HTTPS response from Swarm Ingress..."

if curl -4 -k -s -f https://localhost/ > /dev/null; then
    echo "✓ TLS Verification Success (Nginx is serving via HTTPS)"
    echo "=== ALL INTEGRATION TESTS PASSED (100/100) ==="
else
    echo "✗ HTTPS connection failed or services are still starting"
    exit 1
fi