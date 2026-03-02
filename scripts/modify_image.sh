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

# Set up QEMU user emulation for ARM64 (needed when building on x86_64)
echo "Setting up QEMU emulation for ARM64..."
if command -v update-binfmts &> /dev/null; then
    update-binfmts --enable qemu-aarch64 2>/dev/null || true
fi

# Copy QEMU binary to image if it exists
if [ -f /usr/bin/qemu-aarch64-static ]; then
    mkdir -p "$WORK_DIR"/qemu_setup
    # We'll copy it to the mount later  
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

# Copy QEMU static binary for ARM64 emulation (if available)
if [ -f /usr/bin/qemu-aarch64-static ]; then
    echo "Setting up QEMU static binary for ARM64 emulation..."
    mkdir -p "$MOUNT_ROOT/usr/bin"
    cp /usr/bin/qemu-aarch64-static "$MOUNT_ROOT/usr/bin/"
fi

# Copy resolv.conf for DNS
cp /etc/resolv.conf "$MOUNT_ROOT/etc/resolv.conf" || true

# Get password from environment variable
TA_PASSWORD="${TA_PASSWORD:-}"

if [ -z "$TA_PASSWORD" ]; then
    echo "Error: TA_PASSWORD environment variable is not set"
    echo "Please set it before running: export TA_PASSWORD='your_password'"
    exit 1
fi

# Add the ta user
echo "Adding user 'ta' with password from environment variable..."
chroot "$MOUNT_ROOT" /bin/bash -c '
    USERNAME="ta"
    PASSWORD="'"$TA_PASSWORD"'"
    
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

# System upgrades and package installation
echo "Upgrading system packages..."
chroot "$MOUNT_ROOT" /bin/bash -c '
    apt-get update
    apt-get upgrade -y
    apt-get clean
    apt-get autoclean
'

echo "Installing development dependencies..."
chroot "$MOUNT_ROOT" /bin/bash -c '
    apt-get install -y \
        git \
        zsh \
        gdb \
        libcamera-dev \
        libjpeg-dev \
        libtiff5-dev \
        cmake \
        libboost-program-options-dev \
        libdrm-dev \
        libexif-dev \
        tmux \
        vim \
        curl
    apt-get clean
    apt-get autoclean
'

# Configure swapfile
echo "Configuring swapfile..."
chroot "$MOUNT_ROOT" /bin/bash -c '
    if command -v dphys-swapfile &> /dev/null; then
        dphys-swapfile swapoff || true
        sed -i "s/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/g" /etc/dphys-swapfile
        dphys-swapfile setup
        dphys-swapfile swapon
        echo "Swapfile configured to 1024MB"
    fi
'

# Install and configure Oh My Zsh for root
echo "Installing Oh My Zsh for root..."
chroot "$MOUNT_ROOT" /bin/bash -c '
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || true
    chsh -s /usr/bin/zsh root || true
'

# Install and configure Oh My Zsh for ta user
echo "Installing Oh My Zsh for ta user..."
chroot "$MOUNT_ROOT" /bin/bash -c '
    export RUNZSH=no
    su - ta -c "sh -c \"\\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended 2>/dev/null || true"
    chsh -s /usr/bin/zsh ta || true
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
