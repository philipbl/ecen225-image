#!/bin/bash
#
# ECEn 225 Raspberry Pi Imager
# Downloads the pre-built course image, writes it to an SD card,
# and configures a student user account.
#

set -euo pipefail

# ── Variables ────────────────────────────────────────────────────────────────
IMAGE_VERSION="v10"
RPI_OS_URL="https://github.com/philipbl/ecen225-image/releases/download/${IMAGE_VERSION}/ecen225-rpi-os.img.xz"
IMG_FILE="ecen225-rpi-os.img"
IMG_FILE_XZ="${IMG_FILE}.xz"
BOOT_PARTITION="/media/$(whoami)/bootfs"
ROOT_PARTITION="/media/$(whoami)/rootfs"

# ── Colors & formatting ─────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
NC='\033[0m'

print_header()  { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }
print_success() { echo -e "  ${GREEN}✔${NC} $1"; }
print_error()   { echo -e "  ${RED}✖${NC} $1" >&2; }
print_warn()    { echo -e "  ${YELLOW}!${NC} $1"; }
print_info()    { echo -e "  ${DIM}$1${NC}"; }

# ── Spinner for long-running commands ────────────────────────────────────────
spinner() {
    local pid=$1
    local msg="${2:-Working...}"
    local chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${NC} %s" "${chars:i%${#chars}:1}" "$msg"
        i=$((i + 1))
        sleep 0.1
    done
    printf "\r\033[K"  # clear spinner line
    wait "$pid"
    return $?
}

# ── Cleanup on exit ─────────────────────────────────────────────────────────
cleanup() {
    rm -f "$IMG_FILE" "$IMG_FILE_XZ" 2>/dev/null || true
}
trap cleanup EXIT

# ── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         ECEn 225 — Raspberry Pi SD Card Imager      ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  This script will:"
echo -e "    1. Download the ECEn 225 course image"
echo -e "    2. Write it to your SD card"
echo -e "    3. Configure your student user account"
echo ""
echo -e "  ${RED}${BOLD}⚠  Use a DIFFERENT password than your BYU/CAEDM account.${NC}"
echo ""

# ── Confirm ──────────────────────────────────────────────────────────────────
read -rp "  Would you like to proceed? (y/n): " proceed
if [[ "${proceed,,}" != "y" ]]; then
    echo ""
    print_info "Cancelled."
    exit 0
fi

# ── Plug in SD card ─────────────────────────────────────────────────────────
print_header "SD Card Setup"
echo -e "  Plug the SD card and USB adapter into your computer."
read -rp "  Press Enter once the SD card is plugged in..." _

# ── Credentials ──────────────────────────────────────────────────────────────
print_header "User Account Setup"

# Username (NetID)
while true; do
    read -rp "  Enter your NetID: " username
    if [[ -z "$username" ]]; then
        print_error "NetID cannot be empty."
    elif [[ ! "$username" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]]; then
        print_error "NetID must start with a letter and contain only letters and numbers."
    else
        break
    fi
done

# Password
while true; do
    read -rsp "  Enter password: " password
    echo ""
    if [[ ${#password} -lt 4 ]]; then
        print_error "Password must be at least 4 characters."
        continue
    fi
    read -rsp "  Confirm password: " password_confirm
    echo ""
    if [[ "$password" == "$password_confirm" ]]; then
        print_success "Credentials accepted."
        break
    else
        print_error "Passwords do not match. Please try again."
    fi
done

# Hash password (SHA-512)
hashed_password=$(echo "$password" | openssl passwd -6 -stdin)

# ── Clean up previous run ───────────────────────────────────────────────────
if [[ -f "$IMG_FILE" ]] || [[ -f "$IMG_FILE_XZ" ]]; then
    print_warn "Removing leftover files from a previous run..."
    rm -f "$IMG_FILE" "$IMG_FILE_XZ"
fi

# ── Detect SD card ──────────────────────────────────────────────────────────
print_header "Drive Selection"

available_drives=$(lsblk -d -n -o NAME,SIZE,MODEL,TRAN 2>/dev/null \
    | grep -E '(usb|sd)' \
    | grep -vE '^(nvme|loop)' || true)

# Fallback: just list sdX drives
if [[ -z "$available_drives" ]]; then
    available_drives=$(lsblk -d -n -o NAME,SIZE,MODEL | grep -E '^sd' || true)
fi

if [[ -z "$available_drives" ]]; then
    print_error "No removable drives detected."
    print_info "Make sure your SD card is properly connected and try again."
    exit 1
fi

echo ""
echo -e "  ${BOLD}Available drives:${NC}"
echo -e "  ${DIM}─────────────────────────────────────────────────${NC}"
echo "$available_drives" | while IFS= read -r line; do
    echo -e "    $line"
done
echo -e "  ${DIM}─────────────────────────────────────────────────${NC}"
echo ""

read -rp "  Enter the target drive (e.g., sda): " drive

# Validate drive
if [[ ! "$drive" =~ ^sd[a-z]$ ]]; then
    print_error "/dev/$drive is not a valid sdX device name."
    exit 1
fi

if [[ ! -b "/dev/$drive" ]]; then
    print_error "/dev/$drive does not exist as a block device."
    exit 1
fi

# Confirm destructive write
drive_info=$(lsblk -d -n -o NAME,SIZE,MODEL "/dev/$drive" 2>/dev/null || echo "$drive")
echo ""
print_warn "ALL DATA on /dev/$drive will be erased!"
echo -e "    ${DIM}${drive_info}${NC}"
read -rp "  Are you sure? (yes/no): " confirm
if [[ "${confirm,,}" != "yes" ]]; then
    print_info "Cancelled."
    exit 0
fi

# ── Download image ───────────────────────────────────────────────────────────
print_header "Downloading Image (${IMAGE_VERSION})"
print_info "Source: $RPI_OS_URL"
echo ""
wget --progress=bar:force:noscroll -O "$IMG_FILE_XZ" "$RPI_OS_URL" 2>&1
print_success "Download complete."

# ── Decompress ───────────────────────────────────────────────────────────────
print_header "Decompressing Image"
xz -d "$IMG_FILE_XZ" &
spinner $! "Decompressing ${IMG_FILE_XZ}..."
print_success "Decompression complete."

# ── Write to SD card ────────────────────────────────────────────────────────
print_header "Writing Image to /dev/$drive"
print_info "This may take several minutes..."
echo ""
dd if="$IMG_FILE" of="/dev/$drive" bs=4M status=progress conv=fsync 2>&1
echo ""
print_success "Image written successfully."

# ── Mount partitions ─────────────────────────────────────────────────────────
print_header "Mounting Partitions"
echo -e "  Unplug your USB adapter, then plug it back in."
echo -e "  Mount ${BOLD}both${NC} drives by clicking the USB icons in the sidebar."

while true; do
    read -rp "  Press Enter once both drives are mounted..." _

    boot_ok=false
    root_ok=false

    if [[ -f "$BOOT_PARTITION/cmdline.txt" ]]; then
        boot_ok=true
        print_success "Boot partition (bootfs) mounted."
    else
        print_error "Boot partition not found at $BOOT_PARTITION"
    fi

    if [[ -d "$ROOT_PARTITION/etc/systemd/system" ]]; then
        root_ok=true
        print_success "Root partition (rootfs) mounted."
    else
        print_error "Root partition not found at $ROOT_PARTITION"
    fi

    if $boot_ok && $root_ok; then
        break
    fi

    print_warn "Please mount the missing partition(s) and try again."
done

# ── Write firstrun.sh ───────────────────────────────────────────────────────
print_header "Configuring First-Boot Setup"

cat > "$BOOT_PARTITION/firstrun.sh" <<FIRSTRUN_EOF
#!/bin/bash
# Auto-generated by ECEn 225 Imager — runs once on first boot
set +e

# ── Set hostname ──
/usr/lib/raspberrypi-sys-mods/imager_custom set_hostname doorbell-${username}

# ── Configure user account ──
/usr/lib/userconf-pi/userconf "${username}" '${hashed_password}'

# ── Cleanup first-run ──
rm -f /boot/firstrun.sh
sed -i 's| systemd.run.*||g' /boot/cmdline.txt
exit 0
FIRSTRUN_EOF

chmod +x "$BOOT_PARTITION/firstrun.sh"
print_success "firstrun.sh written."

# ── Patch cmdline.txt ────────────────────────────────────────────────────────
print_info "Updating cmdline.txt to trigger first-boot script..."
sed -i '1 s|$| systemd.run=/boot/firstrun.sh systemd.run_success_action=reboot systemd.unit=kernel-command-line.target|' \
    "$BOOT_PARTITION/cmdline.txt"
print_success "cmdline.txt updated."

# ── Done ─────────────────────────────────────────────────────────────────────
rm -f "$IMG_FILE" "$IMG_FILE_XZ" 2>/dev/null || true

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                    All Done!                         ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Summary${NC}"
echo -e "  ───────────────────────────────────────"
echo -e "  Image:     ECEn 225 ${IMAGE_VERSION}"
echo -e "  Drive:     /dev/$drive"
echo -e "  Hostname:  doorbell-${username}"
echo -e "  Username:  ${username}"
echo -e ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    1. Eject the drive (right-click → Eject)"
echo -e "    2. Insert the SD card into your Raspberry Pi"
echo -e "    3. Power on — first boot may take a couple of minutes"
echo ""
