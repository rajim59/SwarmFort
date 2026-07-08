#!/bin/bash
set -euo pipefail

# SwarmFort - Native Overlay Network Key Rotation (Req 47)

echo "Initiating Native Overlay Network Data Path Cryptographic Key Rotation..."


docker network update --advertise-datapath-encryption-key

echo "✅ Overlay network cryptographic key rotation enforced across cluster nodes."