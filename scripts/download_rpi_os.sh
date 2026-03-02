#!/bin/bash
# Script to download the latest Raspberry Pi OS image

set -e

DOWNLOAD_DIR=$1

if [ -z "$DOWNLOAD_DIR" ]; then
    echo "Usage: $0 <download_directory>"
    exit 1
fi

# Check if image already exists
if ls "$DOWNLOAD_DIR"/*-raspios-*.img.xz 1> /dev/null 2>&1; then
    echo "Latest Raspberry Pi OS image already downloaded"
    exit 0
fi

echo "Fetching latest Raspberry Pi OS download link..."

# Get the download page to find the latest image URL
# Using the Raspberry Pi OS Lite ARM64 release page
RELEASE_PAGE="https://www.raspberrypi.com/software/operating-systems/"

# Alternative direct approach - download from the releases API
# Get the latest release information from the Raspberry Pi download server
DOWNLOAD_URL="https://downloads.raspberrypi.org/raspios_lite_arm64/images"

# Fetch the HTML page and extract the latest folder
# The downloads are organized in folders by release date
LATEST_FOLDER=$(curl -s "$DOWNLOAD_URL/" | grep -o 'href="raspios_lite_arm64-[0-9]*-[0-9]*-[0-9]*/"' | tail -1 | cut -d'"' -f2 | sed 's|/$||')

if [ -z "$LATEST_FOLDER" ]; then
    echo "Failed to find latest Raspberry Pi OS release folder"
    echo "You may need to manually download from: $RELEASE_PAGE"
    exit 1
fi

echo "Latest release folder: $LATEST_FOLDER"

# Now get the image file from within that folder
LATEST_IMAGE=$(curl -s "$DOWNLOAD_URL/$LATEST_FOLDER/" | grep -o 'href="[^"]*\.img\.xz"' | head -1 | cut -d'"' -f2)

if [ -z "$LATEST_IMAGE" ]; then
    echo "Failed to find image file in $LATEST_FOLDER"
    exit 1
fi

DOWNLOAD_LINK="$DOWNLOAD_URL/$LATEST_FOLDER/$LATEST_IMAGE"

echo "Downloading from: $DOWNLOAD_LINK"
cd "$DOWNLOAD_DIR"
curl -L -O "$DOWNLOAD_LINK"

if [ -f "$LATEST_IMAGE" ]; then
    echo "Successfully downloaded: $LATEST_IMAGE"
else
    echo "Failed to download image"
    exit 1
fi
