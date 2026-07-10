#!/bin/bash
set -euo pipefail

# ============================================================
# Chaos Test: Network Latency Injection
# Verify Nginx timeout handling and client retry behavior
# ============================================================

LATENCY="${1:-200ms}"
DURATION="${2:-30}"
INTERFACE="${3:-eth0}"

echo "=== Chaos Test: Network Latency Injection ==="
echo "Interface: $INTERFACE"
echo "Latency: $LATENCY"
echo "Duration: ${DURATION}s"

# Root check
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script requires root privileges (tc command)."
    echo "Run with: sudo $0"
    exit 1
fi

# Verify tc dependency
if ! command -v tc &> /dev/null; then
    echo "ERROR: 'tc' command not found. Install iproute2 package."
    exit 1
fi

# Validate the network interface
if ! ip link show "$INTERFACE" &> /dev/null; then
    echo "ERROR: Interface '$INTERFACE' not found."
    echo "Available interfaces:"
    ip -br link show
    exit 1
fi

echo "Injecting ${LATENCY} latency on ${INTERFACE} for ${DURATION} seconds..."
tc qdisc add dev "$INTERFACE" root netem delay "$LATENCY" 2>/dev/null || {
    echo "Existing qdisc found, replacing..."
    tc qdisc replace dev "$INTERFACE" root netem delay "$LATENCY"
}

# Countdown timer
for ((i=DURATION; i>0; i--)); do
    echo -ne "  Time remaining: ${i}s...\r"
    sleep 1
done
echo ""

# Remove the latency rule
echo "Removing latency rule..."
tc qdisc del dev "$INTERFACE" root netem 2>/dev/null || {
    echo "Warning: Could not remove qdisc (may already be removed)."
}

echo "=== PASS: Latency injection completed. ==="
echo "Verify Nginx timeout behavior and client retries in monitoring dashboards."