#!/bin/sh
# Map the standalone virtual DVB adapter (normally adapter2) into the
# adapter0/*1 names expected by unmodified Enigma2.
# Run after e2_usb_vtunerc.ko is loaded and before Enigma2 starts.
set -eu

VADAPTER="${1:-2}"
A0=/dev/dvb/adapter0
V="/dev/dvb/adapter${VADAPTER}"

[ -d "$A0" ] || { echo "missing $A0" >&2; exit 1; }
[ -d "$V" ] || { echo "missing $V (load e2_usb_vtunerc.ko adapter_nr=${VADAPTER} first)" >&2; exit 1; }

# demux0/dvr0 are created immediately. frontend0 should normally be present
# too because the module probes physical adapter1/frontend0 at load time.
for n in demux0 dvr0; do
    [ -e "$V/$n" ] || { echo "missing $V/$n" >&2; exit 1; }
done

backup_and_link() {
    dst="$1"
    src="$2"
    backup="${dst}.aml"

    if [ -L "$dst" ]; then
        rm -f "$dst"
    elif [ -e "$dst" ]; then
        if [ ! -e "$backup" ]; then
            mv "$dst" "$backup"
        else
            rm -f "$dst"
        fi
    fi
    ln -s "$src" "$dst"
}

# Keep the real Amlogic decoder nodes (video0/audio0) exactly where they are.
# Only the logical tuner-B frontend/demux/DVR/network names are redirected.
backup_and_link "$A0/frontend1" "../adapter${VADAPTER}/frontend0"
backup_and_link "$A0/demux1"    "../adapter${VADAPTER}/demux0"
backup_and_link "$A0/dvr1"      "../adapter${VADAPTER}/dvr0"
if [ -e "$V/net0" ]; then
    backup_and_link "$A0/net1" "../adapter${VADAPTER}/net0"
fi

echo "Standalone USB tuner mapping installed:"
ls -l "$A0/frontend1" "$A0/demux1" "$A0/dvr1" 2>/dev/null || true
echo "Physical USB remains: /dev/dvb/adapter1/frontend0 + demux0 + dvr0"
echo "Amlogic decoder remains: /dev/dvb/adapter0/video0 + audio0"
