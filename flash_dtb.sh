#!/bin/sh
# BusyBox-compatible DTB updater.
# Downloads dtb.img, backs up /dev/dtb, and flashes using dd.
# The downloaded image and this script are removed when it exits.

set -eu

URL='https://raw.githubusercontent.com/Mike1250/mike/refs/heads/main/dtb.img'
DEVICE='/dev/dtb'
IMAGE="/tmp/dtb_flash_$$.img"
BACKUP_DIR="${BACKUP_DIR:-/root}"
BACKUP="${BACKUP_DIR%/}/dtb-backup-$(date +%Y%m%d-%H%M%S).img"

cleanup() {
    rm -f "$IMAGE"
    # Only self-delete when invoked from the temporary directory.
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
if [ ! -d "$BACKUP_DIR" ] || [ ! -w "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory is not writable: $BACKUP_DIR" >&2
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
    echo 'ERROR: Downloaded DTB is empty.' >&2
    exit 1
fi

printf 'Backing up %s to %s ...\n' "$DEVICE" "$BACKUP"
dd if="$DEVICE" of="$BACKUP" bs=1M || {
    echo 'ERROR: Backup failed. The DTB was not flashed.' >&2
    rm -f "$BACKUP"
    exit 1
}
sync

IMAGE_SIZE=$(wc -c < "$IMAGE")
BACKUP_SIZE=$(wc -c < "$BACKUP")
if [ "$BACKUP_SIZE" -eq 0 ] || [ "$IMAGE_SIZE" -gt "$BACKUP_SIZE" ]; then
    echo "ERROR: Image size ($IMAGE_SIZE bytes) exceeds readable DTB partition ($BACKUP_SIZE bytes), or the backup is empty." >&2
    echo "Backup kept at: $BACKUP" >&2
    exit 1
fi

printf 'Flashing %s (%s bytes) to %s ...\n' "$IMAGE" "$IMAGE_SIZE" "$DEVICE"
dd if="$IMAGE" of="$DEVICE" bs=1M
sync
printf '%s\n' 'DTB flash completed successfully.'
printf 'Original DTB backup saved at: %s\n' "$BACKUP"
printf '%s\n' 'Downloaded files will be removed automatically.'
