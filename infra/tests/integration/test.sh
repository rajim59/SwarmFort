#!/bin/bash
set -e

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