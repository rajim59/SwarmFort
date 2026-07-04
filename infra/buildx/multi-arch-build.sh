#!/bin/bash
set -euo pipefail

# ============================================================
# মাল্টি-আর্কিটেকচার ইমেজ বিল্ড
# ============================================================

REGISTRY="${DOCKER_REGISTRY:-myrepo}"
IMAGE_NAME="${IMAGE_NAME:-swarmfort-api}"
TAG="${TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

echo "Building multi-arch image: $REGISTRY/$IMAGE_NAME:$TAG"
echo "Platforms: $PLATFORMS"

# --push ফ্ল্যাগটি সরিয়ে দেওয়া হয়েছে টেস্টিংয়ের জন্য
docker buildx build \
    --platform "$PLATFORMS" \
    --tag "$REGISTRY/$IMAGE_NAME:$TAG" \
    --file app/Dockerfile \
    .

echo "Multi-arch build completed successfully."