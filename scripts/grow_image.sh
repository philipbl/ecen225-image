#!/bin/bash
# Script to grow the Raspberry Pi OS image size

set -e

BUILD_DIR=$1
ADDITIONAL_SIZE=${2:-1024}  # Default: add 1GB, in MB

if [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <build_directory> [additional_size_mb]"
    exit 1
fi

WORK_DIR="$BUILD_DIR/image_work"
IMAGE=$(ls "$WORK_DIR"/*.img 2>/dev/null | head -1)

if [ -z "$IMAGE" ]; then
    echo "No extracted image found in $WORK_DIR"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

echo "Growing image by ${ADDITIONAL_SIZE}MB..."
echo "Current image size:"
ls -lh "$IMAGE"

# Add space to the image file
dd if=/dev/zero bs=1M count="$ADDITIONAL_SIZE" >> "$IMAGE"

echo "New image size:"
ls -lh "$IMAGE"

# Setup loop device
echo "Setting up loop device..."
LOOP_DEVICE=$(losetup -f --show -P "$IMAGE")

if ! [ -b "${LOOP_DEVICE}p2" ]; then
    echo "Failed to create loop device partitions"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi

echo "Loop device: $LOOP_DEVICE"

# Get the root partition number (usually p2)
ROOT_PARTITION="${LOOP_DEVICE}p2"

# Expand the partition to fill the new space
echo "Expanding root partition..."
parted -s "$LOOP_DEVICE" resizepart 2 100%

# Wait for partition changes to be registered
sleep 2

# Resize the filesystem
echo "Resizing filesystem..."
resize2fs "$ROOT_PARTITION"

echo "Image growth complete"

# Detach loop device
losetup -d "$LOOP_DEVICE"

echo "Final image size:"
ls -lh "$IMAGE"
