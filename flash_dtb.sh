#!/bin/sh
# BusyBox-compatible DTB updater (NO BACKUP).
# Downloads dtb.img, flashes /dev/dtb, and removes temporary files.

set -eu

URL='https://raw.githubusercontent.com/Mike1250/mike/refs/heads/main/dtb.img'
DEVICE='/dev/dtb'
IMAGE="/tmp/dtb_flash_$$.img"

cleanup() {
    rm -f "$IMAGE"
    # Remove the downloaded script only when it lives under /tmp.
    case "$0" in
        /tmp/*.sh) rm -f "$0" ;;
    esac
}
trap cleanup EXIT

if [ "$(id -u)" != '0' ]; then
    echo 'ERROR: Run this script as root.' >&2
    exit 1
fi
if [ ! -b "$DEVICE" ] && [ ! -c "$DEVICE" ]; then
    echo "ERROR: $DEVICE is not a block or character device." >&2
    exit 1
fi

printf '%s\n' 'Downloading DTB image...'
if command -v wget >/dev/null 2>&1; then
    wget -O "$IMAGE" "$URL"
elif command -v curl >/dev/null 2>&1; then
    curl -fL -o "$IMAGE" "$URL"
else
    echo 'ERROR: Neither wget nor curl is available.' >&2
    exit 1
fi

if [ ! -s "$IMAGE" ]; then
    echo 'ERROR: Downloaded DTB image is empty.' >&2
    exit 1
fi

IMAGE_SIZE=$(wc -c < "$IMAGE")

# Check capacity when the device exposes it (not always available on Enigma2).
DEVICE_SIZE=''
if [ -b "$DEVICE" ] && command -v blockdev >/dev/null 2>&1; then
    DEVICE_SIZE=$(blockdev --getsize64 "$DEVICE" 2>/dev/null || true)
fi
case "$DEVICE_SIZE" in
    ''|*[!0-9]*) ;;
    *)
        if [ "$DEVICE_SIZE" -gt 0 ] && [ "$IMAGE_SIZE" -gt "$DEVICE_SIZE" ]; then
            echo "ERROR: DTB image ($IMAGE_SIZE bytes) exceeds device size ($DEVICE_SIZE bytes)." >&2
            exit 1
        fi
        ;;
esac

printf 'Flashing %s (%s bytes) to %s ...\n' "$IMAGE" "$IMAGE_SIZE" "$DEVICE"
dd if="$IMAGE" of="$DEVICE" bs=1M
sync
printf '%s\n' 'DTB flash completed successfully.'
printf '%s\n' 'Temporary files will be removed automatically.'
