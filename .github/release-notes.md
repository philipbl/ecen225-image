# Raspberry Pi OS Image Release

This is an automatically generated Raspberry Pi OS image with the following modifications:

## Modifications Applied
- System upgrade (apt upgrade)
- Development tools and libraries installed:
  - Git, Zsh, GDB, CMake
  - Camera and image processing libraries (libcamera-dev, libjpeg-dev, libtiff5-dev)
  - Boost libraries (libboost-program-options-dev)
  - DRM and media libraries (libdrm-dev, libexif-dev)
  - Utilities: tmux, vim, curl
- Swapfile configured to 1024MB
- Oh My Zsh installed for both root and ta user
- Default shell changed to Zsh
- Added system user `ta`

## How to Use
1. Download the `ecen225-rpi-os.img.xz` file
2. Extract the compressed image:
   ```bash
   xz -d ecen225-rpi-os.img.xz
   ```
3. Write it to an SD card using:
   ```bash
   sudo dd if=ecen225-rpi-os.img of=/dev/rdiskX bs=4m
   sudo diskutil eject /dev/diskX
   ```
   Replace `X` with your SD card's disk number (use `diskutil list` to find it)
4. Insert the SD card into your Raspberry Pi and boot
