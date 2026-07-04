#!/bin/bash
set -euo pipefail

# ============================================================
# DCT রুট কী ও টার্গেট কী রোটেশন
# ============================================================
# সতর্কতা: রুট কী অফলাইনে রাখতে হবে; এই স্ক্রিপ্ট অনলাইন ম্যানেজারে চালানো বিপজ্জনক।
# এটি শুধুমাত্র টার্গেট/স্ন্যাপশট কী রোটেট করবে (ডেলিগেশন)।

REPO="${1:-myrepo/swarmfort-api}"

echo "Rotating target/snapshot keys for $REPO..."

# ব্যাকআপ পুরনো কী
mkdir -p ~/.docker/trust/backup-$(date +%Y%m%d)
cp -r ~/.docker/trust/private ~/.docker/trust/backup-$(date +%Y%m%d)/ || true

# নতুন টার্গেট কী জেনারেট
docker trust key generate target-$(date +%s) --dir ~/.docker/trust/private
echo "New target key generated. Please update delegation roles if needed."

# সাইনিং পলিসি আপডেট (নতুন কী দিয়ে)
echo "Re-signing with new key..."
docker trust signer add --key ~/.docker/trust/private/target-*.pub signer "$REPO"
docker trust sign "$REPO"

echo "Rotation complete. Old keys backed up."