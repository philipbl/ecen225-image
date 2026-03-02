# ECEN 225 Raspberry Pi OS Image Builder

Automated tooling to build and customize Raspberry Pi OS images with Continuous Integration/Continuous Deployment via GitHub Actions.

## Features

- **Automated Image Download**: Fetches the latest Raspberry Pi OS Lite (ARM64) image
- **Image Customization**: Modifies the image to add users and configure system settings
- **CI/CD Integration**: GitHub Actions workflow for automated builds
- **Easy Deployment**: Makefile-based build system

## Current Modifications

This build applies the following modifications to Raspberry Pi OS:
- Adds system user `ta` with a secure password (set via environment variable)
- Grants sudo access to the `ta` user

## Prerequisites

### Local Building
- Linux system with `sudo` access
- Tools: `curl`, `xz-utils`, `fdisk`, `losetup`, `mount`
- At least 4GB free disk space for downloading and building

**Installation on Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y curl xz-utils fdisk
```

### GitHub Actions
The workflow runs automatically on Ubuntu runners with all dependencies pre-installed.

**Required GitHub Secret:**
Before running the workflow, you must configure the `TA_PASSWORD` secret in your repository:

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `TA_PASSWORD`
5. Value: Your desired password for the `ta` user
6. Click "Add secret"

## Usage

### Building Locally

**Important:** You must set the `TA_PASSWORD` environment variable before building:

```bash
# Set the password for the ta user
export TA_PASSWORD='your_secure_password'

# Display available commands
make help

# Build the complete image (download, extract, modify, package)
sudo -E make build

# Or step by step:
sudo -E make download      # Download latest Raspberry Pi OS
sudo -E make extract       # Extract the compressed image
sudo -E make modify-image  # Mount and modify the image
sudo make clean            # Clean up all artifacts
```

**Note:** The `-E` flag preserves environment variables when using `sudo`.

### Automated Builds via GitHub Actions

The project includes a GitHub Actions workflow (`.github/workflows/build-image.yml`) that:

1. **Triggers on**:
   - Push to main branch
   - Pull requests
   - Manual workflow dispatch
   - Weekly schedule (Monday 00:00 UTC)

2. **Builds the image** using the Makefile
3. **Creates releases** with the modified image as an artifact
4. **Uploads artifacts** for 30 days

### Accessing Build Artifacts

1. **From GitHub UI**:
   - Go to Actions tab
   - Select the latest workflow run
   - Download artifacts from the run summary

2. **From Release Page**:
   - Go to Releases
   - Download the image from the latest release

## Writing to SD Card

### macOS
```bash
# Find your SD card
diskutil list

# Unmount (replace X with your disk number)
diskutil unmountDisk /dev/diskX

# Write image
sudo dd if=ecen225-rpi-os.img of=/dev/rdiskX bs=4m
sudo diskutil eject /dev/diskX
```

### Linux
```bash
# Find your SD card
lsblk

# Unmount (replace sdX with your device)
sudo umount /dev/sdX*

# Write image
sudo dd if=ecen225-rpi-os.img of=/dev/sdX bs=4M status=progress
sudo sync
```

## Image Structure

```
.
├── .github/
│   ├── workflows/
│   │   └── build-image.yml       # GitHub Actions workflow
│   └── release-notes.md          # Release template
├── scripts/
│   ├── download_rpi_os.sh        # Download latest image
│   ├── extract_image.sh          # Extract compressed image
│   ├── modify_image.sh           # Mount and customize image
│   └── package_image.sh          # Package final image
├── Makefile                      # Build orchestration
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Build Directory Structure

After building, the following directories are created:

```
downloads/                         # Downloaded image
build/image_work/                  # Extracted and modified image
dist/                              # Final output image
```

## Default User Credentials

When you boot the image for the first time:

- **Username**: `ta`
- **Password**: Set via `TA_PASSWORD` environment variable during build
- **Sudo Access**: Yes

**Security Note:** 
- Never commit passwords to your repository
- Always use GitHub Secrets for automated builds
- Change the default password after first login for production use
- Use strong, unique passwords (minimum 12 characters recommended)

## Customizing the Build

To add additional modifications to the image:

1. Edit `scripts/modify_image.sh` to add your customizations in the `chroot` section
2. The script runs with full root access within the mounted image
3. Common modifications:
   - Install packages: `apt-get install -y package-name`
   - Create directories: `mkdir -p /path/to/dir`
   - Copy files from host: Use bind mounts before modifications

Example of adding a package:
```bash
chroot "$MOUNT_ROOT" /bin/bash -c '
    apt-get update
    apt-get install -y git python3
'
```

## Troubleshooting

### "Error: TA_PASSWORD environment variable is not set"
You must set the password before building:
```bash
export TA_PASSWORD='your_secure_password'
sudo -E make build
```
For GitHub Actions, ensure the `TA_PASSWORD` secret is configured in repository settings.

### "This script must be run as root"
Use `sudo -E make build` instead of just `make build` (the `-E` flag preserves environment variables)

### "No extracted image found"
Make sure you run `make download` before other targets, or use `make build`

### "Failed to create loop device partitions"
This usually means:
- You don't have permission to use loop devices
- Run with `sudo`
- Check that `/dev/loop*` devices exist

### Image is too large
The image size matches the original Raspberry Pi OS size. To reduce it:
- Use `zerofill` on empty space before packaging
- Compress the output image with `xz`

## Contributing

To extend this project:
1. Fork the repository
2. Create a feature branch
3. Make modifications to scripts or Makefile
4. Test locally with `sudo make build`
5. Submit a pull request

## License

This project provides automation for Raspberry Pi OS. Raspberry Pi OS is licensed under the GNU General Public License v3.0. See the [Raspberry Pi Foundation website](https://www.raspberrypi.org) for details.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review script output for specific error messages
3. Open an issue on GitHub with details about your setup

## References

- [Raspberry Pi OS Downloads](https://www.raspberrypi.com/software/operating-systems/)
- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
