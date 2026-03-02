#!/bin/bash
# Script to package the modified image

set -e

BUILD_DIR=$1
OUTPUT_DIR=$2
IMAGE_NAME=$3

if [ -z "$BUILD_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$IMAGE_NAME" ]; then
    echo "Usage: $0 <build_directory> <output_directory> <image_name>"
    exit 1
fi

WORK_DIR="$BUILD_DIR/image_work"
IMAGE=$(ls "$WORK_DIR"/*.img 2>/dev/null | head -1)

if [ -z "$IMAGE" ]; then
    echo "No image found in $WORK_DIR"
    exit 1
fi

echo "Packaging image..."

# Copy the modified image to output directory
output_path="$OUTPUT_DIR/$IMAGE_NAME.img"
cp "$IMAGE" "$output_path"

echo "Image packaged: $output_path"
echo "Image size:"
ls -lh "$output_path"

# Compress the image to reduce size (GitHub has 2GB limit for release assets)
echo "Compressing image with xz (this may take several minutes)..."
xz -9 -v "$output_path"

compressed_path="$output_path.xz"
echo "Compressed image: $compressed_path"
echo "Compressed size:"
ls -lh "$compressed_path"
