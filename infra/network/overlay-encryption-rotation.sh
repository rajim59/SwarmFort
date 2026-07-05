#!/bin/bash
set -euo pipefail

# ============================================================
# SwarmFort - Native Overlay Network Key Rotation (Req 47)
# ============================================================

echo "Initiating Native Overlay Network Data Path Cryptographic Key Rotation..."

# ডকার সোয়ার্মের ব্যাকগ্রাউন্ড রাউটিং মেশিনের ক্রিপ্টোগ্রাফিক কী চেঞ্জ করার স্ট্যান্ডার্ড কমান্ড
docker network update --advertise-datapath-encryption-key

echo "✅ Overlay network cryptographic key rotation enforced across cluster nodes."