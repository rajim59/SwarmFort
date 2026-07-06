#!/bin/bash
set -euo pipefail

# ============================================================
# multi-arch-build 
# ============================================================

REGISTRY="${DOCKER_REGISTRY:-myrepo}"
IMAGE_NAME="${IMAGE_NAME:-swarmfort-api}"
TAG="${TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

echo "Building multi-arch image: $REGISTRY/$IMAGE_NAME:$TAG"
echo "Platforms: $PLATFORMS"


docker buildx build \
    --platform "$PLATFORMS" \
    --tag "$REGISTRY/$IMAGE_NAME:$TAG" \
    --file app/Dockerfile \
    .

echo "Multi-arch build completed successfully."