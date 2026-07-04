#!/bin/bash
set -euo pipefail

# ============================================================
# buildx মাল্টি-আর্কিটেকচার বিল্ডার সেটআপ
# ============================================================

BUILDER_NAME="${BUILDER_NAME:-multiarch-builder}"

if docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
    echo "Builder '$BUILDER_NAME' already exists."
    docker buildx use "$BUILDER_NAME"
else
    echo "Creating new builder '$BUILDER_NAME'..."
    docker buildx create --name "$BUILDER_NAME" --use --driver docker-container
    docker buildx inspect --bootstrap
fi

echo "Buildx builder '$BUILDER_NAME' is ready."