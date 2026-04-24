# Raspberry Pi OS Image Release

This is an automatically generated Raspberry Pi OS image with the following modifications:

## Modifications Applied
- System upgrade (apt upgrade)
- Development tools and libraries installed:
  - Git, Zsh, GDB, CMake
  - Camera and image processing libraries (libcamera-dev, libjpeg-dev, libtiff5-dev)
  - Boost libraries (libboost-program-options-dev)
  - DRM and media libraries (libdrm-dev, libexif-dev)
  - Utilities: tmux, vim, curl, emacs
- Swapfile configured to 1024MB
- Added system user `ta`
- Installed `ip_addr` binary with systemd service

## How to Use
1. Download `imager.sh` from the repository:
   ```bash
   wget https://raw.githubusercontent.com/philipbl/ecen225-image/main/imager.sh
   chmod +x imager.sh
   ```
2. Plug in your SD card via USB adapter.
3. Run the imager:
   ```bash
   ./imager.sh
   ```
   The script will prompt for your NetID and password, download the image, decompress it, write it to the SD card, and configure first-boot cloud-init.
4. Insert the SD card into your Raspberry Pi and boot.
