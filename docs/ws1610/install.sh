#!/bin/sh
# Huasifei WS1610 - install the hanwckf U-Boot FIP on an all-in-UBI device.
#
# Run this ON THE ROUTER (OpenWrt) as root.
# It only updates the UBI 'fip' volume. It does not touch BL2, factory data,
# the FIT image, or rootfs_data.
set -eu

RELEASE_TAG="ws1610-v1"
FIP_NAME="mt7981_huasifei_ws1610-fip-fixed-parts.bin"
FIP_SHA256="4d64aa9de13235fcf83fba21f676957e30ee740197cc5160fc51295b854a81dc"
FIP_URL="https://github.com/nerdjb/bl-mt798x/releases/download/${RELEASE_TAG}/${FIP_NAME}"

REBOOT=0
FIP=""

usage() {
    cat <<EOF
Usage: sh install.sh [--yes] [FIP_FILE]

  FIP_FILE   Use a local FIP file instead of downloading it from GitHub.
  --yes, -y  Reboot automatically after a successful write.
  --force    Continue even if the board name is not WS1610.

The script updates only the UBI 'fip' volume. It does not touch BL2.
EOF
}

FORCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) REBOOT=1 ;;
        --force) FORCE=1 ;;
        --help|-h) usage; exit 0 ;;
        -*) echo "Unknown option: $1"; usage; exit 1 ;;
        *) FIP="$1" ;;
    esac
    shift
done

[ "$(id -u)" = "0" ] || { echo "ERROR: run as root"; exit 1; }

for cmd in ubinfo ubiupdatevol sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: missing required command: $cmd"
        exit 1
    }
done

BOARD="$(cat /tmp/sysinfo/board_name 2>/dev/null || true)"
MODEL="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || true)"
if ! echo "$BOARD $MODEL" | grep -qi ws1610; then
    echo "WARNING: this does not look like a Huasifei WS1610."
    echo "         board='$BOARD' model='$MODEL'"
    if [ "$FORCE" != "1" ]; then
        echo "Refusing to continue. Use --force only if you are sure."
        exit 1
    fi
fi

# This installer requires the OpenWrt all-in-UBI layout.
if ! ubinfo -d 0 -N fip >/dev/null 2>&1; then
    echo "ERROR: UBI volume 'fip' not found."
    echo "This device is not using the all-in-UBI layout."
    echo "Convert it first; see docs/ws1610/README.md."
    exit 1
fi

FIP_ID="$(ubinfo -a | awk '/Volume ID:/{id=$3} /Name:[[:space:]]*fip$/{print id; exit}')"
[ -n "$FIP_ID" ] || { echo "ERROR: cannot determine fip volume ID"; exit 1; }

TYPE="$(ubinfo -d 0 -N fip | awk '/Type:/{print $2; exit}')"
[ "$TYPE" = "static" ] || {
    echo "ERROR: fip volume is not static (type: $TYPE)"
    exit 1
}

VOL_SIZE="$(ubinfo -d 0 -N fip | awk '/Size:/{print $2; exit}')"
[ -n "$VOL_SIZE" ] || { echo "ERROR: cannot determine fip volume size"; exit 1; }

if [ -z "$FIP" ]; then
    FIP="/tmp/$FIP_NAME"
    echo "Downloading $FIP_URL"
    if command -v wget >/dev/null 2>&1; then
        wget -O "$FIP" "$FIP_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$FIP" "$FIP_URL"
    else
        echo "ERROR: neither wget nor curl found"
        exit 1
    fi
fi

[ -f "$FIP" ] || { echo "ERROR: FIP file not found: $FIP"; exit 1; }

echo "Verifying SHA256..."
if ! echo "$FIP_SHA256  $FIP" | sha256sum -c -; then
    echo "ERROR: checksum mismatch. Refusing to write."
    exit 1
fi

FIP_SIZE="$(wc -c < "$FIP" | tr -d ' ')"
if [ "$FIP_SIZE" -gt "$VOL_SIZE" ]; then
    echo "ERROR: FIP is $FIP_SIZE bytes, but the fip volume is only $VOL_SIZE bytes."
    echo "Use the U-Boot web failsafe or serial TFTP method instead."
    exit 1
fi

# Keep the overlay volume if it already exists.
if ! ubinfo -d 0 -N rootfs_data >/dev/null 2>&1; then
    echo "Creating missing rootfs_data volume..."
    ubimkvol /dev/ubi0 -N rootfs_data -m || {
        echo "WARNING: could not create rootfs_data; the system may boot read-only"
    }
fi

BACKUP="/root/ws1610-fip-backup.bin"
if ! cat "/dev/ubi0_$FIP_ID" > "$BACKUP" 2>/dev/null; then
    BACKUP="/tmp/ws1610-fip-backup.bin"
    cat "/dev/ubi0_$FIP_ID" > "$BACKUP" 2>/dev/null || true
fi
if [ -s "$BACKUP" ]; then
    echo "Old FIP backed up to $BACKUP"
else
    echo "WARNING: could not back up the old FIP"
fi

echo "Writing $FIP ($FIP_SIZE bytes) to UBI volume fip (id $FIP_ID)..."
if ! ubiupdatevol "/dev/ubi0_$FIP_ID" "$FIP"; then
    echo "ERROR: ubiupdatevol failed."
    echo "Do not reboot until you verify the fip volume."
    exit 1
fi

sync
echo "SUCCESS: hanwckf U-Boot FIP written."
echo "The new U-Boot will be used on the next reboot."

if [ "$REBOOT" = "1" ]; then
    echo "Rebooting..."
    reboot
else
    echo "Reboot with: reboot"
fi
