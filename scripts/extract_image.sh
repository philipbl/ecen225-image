#!/bin/bash
# Script to extract the Raspberry Pi OS image

set -e

DOWNLOAD_DIR=$1
BUILD_DIR=$2

if [ -z "$DOWNLOAD_DIR" ] || [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <download_directory> <build_directory>"
    exit 1
fi

# Find the downloaded image
IMAGE=$(ls "$DOWNLOAD_DIR"/*-raspios-*.img.xz 2>/dev/null | head -1)

if [ -z "$IMAGE" ]; then
    echo "No Raspberry Pi OS image found in $DOWNLOAD_DIR"
    exit 1
fi

IMAGE_NAME=$(basename "$IMAGE" .xz)
WORK_DIR="$BUILD_DIR/image_work"

mkdir -p "$WORK_DIR"

# Check if already extracted
if [ -f "$WORK_DIR/$IMAGE_NAME" ]; then
    echo "Image already extracted"
    exit 0
fi

echo "Extracting $IMAGE_NAME..."
xz -d -c "$IMAGE" > "$WORK_DIR/$IMAGE_NAME"

if [ -f "$WORK_DIR/$IMAGE_NAME" ]; then
    echo "Successfully extracted image"
else
    echo "Failed to extract image"
    exit 1
fi
