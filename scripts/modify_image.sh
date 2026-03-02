#!/bin/bash
# Script to mount and modify the Raspberry Pi OS image

set -e

BUILD_DIR=$1

if [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <build_directory>"
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

MOUNT_DIR="$WORK_DIR/mnt"
MOUNT_BOOT="$MOUNT_DIR/boot"
MOUNT_ROOT="$MOUNT_DIR/root"

# Function to cleanup on error
cleanup() {
    echo "Cleaning up mounts..."
    # Unmount in reverse order
    umount "$MOUNT_BOOT" 2>/dev/null || true
    umount "$MOUNT_ROOT" 2>/dev/null || true
    rmdir "$MOUNT_DIR" "$MOUNT_BOOT" "$MOUNT_ROOT" 2>/dev/null || true
}

trap cleanup ERR EXIT

mkdir -p "$MOUNT_DIR"

echo "Getting image partition information..."
# Use fdisk to get partition offsets
PARTITION_INFO=$(fdisk -l "$IMAGE" | grep "^$IMAGE")

# Extract partition starts (in sectors, 512 bytes each)
# Typically: partition 1 is boot, partition 2 is root
LOOP_SET=$(losetup -f --show -P "$IMAGE")
LOOP_DEVICE=${LOOP_SET%$'\n'}

echo "Loop device: $LOOP_DEVICE"

if ! [ -b "${LOOP_DEVICE}p1" ]; then
    echo "Failed to create loop device partitions"
    losetup -d "$LOOP_DEVICE"
    exit 1
fi

# Mount both partitions
mkdir -p "$MOUNT_BOOT" "$MOUNT_ROOT"
echo "Mounting boot partition..."
mount "${LOOP_DEVICE}p1" "$MOUNT_BOOT" || true

echo "Mounting root partition..."
mount "${LOOP_DEVICE}p2" "$MOUNT_ROOT"

# Setup bind mounts for chroot
echo "Setting up chroot environment..."
mount --bind /dev "$MOUNT_ROOT/dev"
mount --bind /sys "$MOUNT_ROOT/sys"
mount --bind /proc "$MOUNT_ROOT/proc"
mount -t devpts /dev/pts "$MOUNT_ROOT/dev/pts"

# Copy resolv.conf for DNS
cp /etc/resolv.conf "$MOUNT_ROOT/etc/resolv.conf" || true

# Add the ta user
echo "Adding user 'ta' with password 'ecen225'..."
chroot "$MOUNT_ROOT" /bin/bash -c '
    USERNAME="ta"
    PASSWORD="ecen225"
    
    # Create user with home directory
    if ! id -u "$USERNAME" > /dev/null 2>&1; then
        useradd -m -s /bin/bash "$USERNAME" || true
    fi
    
    # Set password (using echo + chpasswd for reliability)
    echo "$USERNAME:$PASSWORD" | chpasswd
    
    # Add to sudo group
    usermod -aG sudo "$USERNAME" || true
    
    echo "User $USERNAME created successfully"
'

echo "Image modification complete"

# Cleanup bind mounts
umount "$MOUNT_ROOT/dev/pts" 2>/dev/null || true
umount "$MOUNT_ROOT/proc" 2>/dev/null || true
umount "$MOUNT_ROOT/sys" 2>/dev/null || true
umount "$MOUNT_ROOT/dev" 2>/dev/null || true

echo "Unmounting partitions..."
umount "$MOUNT_BOOT" 2>/dev/null || true
umount "$MOUNT_ROOT"

# Detach loop device
losetup -d "$LOOP_DEVICE"

echo "Image modification complete"
