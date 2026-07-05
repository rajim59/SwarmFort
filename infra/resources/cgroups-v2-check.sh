#!/bin/bash
set -euo pipefail
mount | grep -q "cgroup2 on /sys/fs/cgroup type cgroup2" && echo "cgroups v2 is active." || {
    echo "ERROR: cgroups v2 not active" >&2; exit 1; }
[ "$(docker info --format '{{.CgroupDriver}}')" = "systemd" ] && echo "Docker cgroup driver is systemd." || echo "WARN: driver mismatch"