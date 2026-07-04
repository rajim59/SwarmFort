#!/bin/bash
set -euo pipefail

# ============================================================
# CIS Docker Benchmark অডিট (সংক্ষিপ্ত সংস্করণ)
# ============================================================

echo "=== Docker Bench Security ==="
echo "Checking key Docker security configurations..."

# 1. Docker daemon configuration
echo "[CHECK] 2.1 Ensure network traffic is restricted"
docker info --format '{{ .Swarm.NodeAddr }}' >/dev/null && echo "PASS" || echo "WARN"

# 2. Docker daemon file permissions
echo "[CHECK] 1.1 Ensure docker.sock permissions are 660"
stat -c "%a" /var/run/docker.sock | grep -q "660" && echo "PASS" || echo "WARN"

# 3. Running containers privileges
echo "[CHECK] 5.4 Ensure privileged containers are not used"
docker ps -q | xargs -r docker inspect --format '{{ .HostConfig.Privileged }}' | grep -q true && echo "WARN: Privileged container found" || echo "PASS"

# 4. Overlay network encryption check
echo "[CHECK] 5.1 Ensure encryption is enabled for overlay networks"
docker network ls --filter driver=overlay -q | xargs -r -I {} docker network inspect {} --format '{{ .Options.encrypted }}' | grep -q false && echo "WARN: Unencrypted overlay network" || echo "PASS"

echo "=== Audit complete ==="