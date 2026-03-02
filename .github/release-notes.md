# Raspberry Pi OS Image Release

This is an automatically generated Raspberry Pi OS image with the following modifications:

## Modifications Applied
- Added system user `ta` with password `ecen225`
- User has sudo access

## How to Use
1. Download the `ecen225-rpi-os.img` file
2. Write it to an SD card using:
   ```bash
   sudo dd if=ecen225-rpi-os.img of=/dev/rdiskX bs=4m
   sudo diskutil eject /dev/diskX
   ```
   Replace `X` with your SD card's disk number (use `diskutil list` to find it)
3. Insert the SD card into your Raspberry Pi and boot

## Default Credentials
- **User**: ta
- **Password**: ecen225
- **Sudo**: Enabled

## Image Build Date
Generated on: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
