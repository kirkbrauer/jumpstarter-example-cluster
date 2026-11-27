#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Builds the disk image of the Linux head unit: a Debian 13 cloud image, booted once in QEMU with provision.sh
# as its first-boot script, and kept as it is when that has finished.
#
#   ./build.sh [amd64|arm64]        (default: amd64, what the lab's QEMU devices are)
#
# It needs qemu-system-<arch>, qemu-img, curl and python3, and the frame bridge of jumpstarter-driver-wifi
# (one file): WMEDIUMD_AGENT is where it is, a path or a URL. The image is ./out/headunit-linux-<arch>.qcow2.
# On a machine of the same architecture with KVM or HVF it takes a few minutes; emulated, much longer.
set -euo pipefail
cd "$(dirname "$0")"

ARCH="${1:-amd64}"
LIVI_VERSION="${LIVI_VERSION:-10.5.0}"
DEBIAN_IMAGE="${DEBIAN_IMAGE:-https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-$ARCH.qcow2}"
WMEDIUMD_AGENT="${WMEDIUMD_AGENT:?where wmediumd_agent.py of jumpstarter-driver-wifi is: a path or a URL}"
DISK_SIZE="${DISK_SIZE:-8G}"
CACHE="${CACHE:-./cache}"
OUT=./out
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$CACHE" "$OUT"

case "$ARCH" in
    amd64) qemu=qemu-system-x86_64; machine=q35; livi=x64; host=x86_64 ;;
    arm64) qemu=qemu-system-aarch64; machine=virt; livi=arm64; host="arm64 aarch64" ;;
    *) echo "amd64 or arm64" >&2; exit 2 ;;
esac

fetch() { # url file
    [ -s "$2" ] || { echo "fetching $1"; curl --fail --location --silent --show-error --retry 3 -o "$2.part" "$1"; mv "$2.part" "$2"; }
}
fetch "$DEBIAN_IMAGE" "$CACHE/debian-13-generic-$ARCH.qcow2"
fetch "https://github.com/f-io/LIVI/releases/download/v$LIVI_VERSION/LIVI-$LIVI_VERSION-linux-$livi.AppImage" \
    "$CACHE/LIVI-$LIVI_VERSION-$livi.AppImage"

# What provision.sh installs.
mkdir "$WORK/files"
cp provision.sh headunit-bluetooth-attach headunit-bluetooth.service headunit-wifi-bridge.service \
    livi-kiosk.service "$WORK/files/"
cp "$CACHE/LIVI-$LIVI_VERSION-$livi.AppImage" "$WORK/files/LIVI.AppImage"
case "$WMEDIUMD_AGENT" in
    http://*|https://*) curl --fail --location --silent --show-error -o "$WORK/files/wmediumd_agent.py" "$WMEDIUMD_AGENT" ;;
    *) cp "$WMEDIUMD_AGENT" "$WORK/files/wmediumd_agent.py" ;;
esac
# The first boot: cloud-init is given its data, and the files, by a web server here (10.0.2.2 is this machine,
# as QEMU's own network shows it to the guest). It fetches the files, runs provision.sh and powers off;
# `headunit-image-done` on the console says that it went well.
printf 'instance-id: headunit-build\nlocal-hostname: headunit\n' > "$WORK/files/meta-data"
: > "$WORK/files/vendor-data"
cat > "$WORK/files/user-data" <<'SEED'
#cloud-config
runcmd:
  - mkdir -p /run/headunit-build
  - |
    python3 - <<'PY'
    import urllib.request
    for name in ("provision.sh", "headunit-bluetooth-attach", "headunit-bluetooth.service",
                 "headunit-wifi-bridge.service", "livi-kiosk.service", "wmediumd_agent.py", "LIVI.AppImage"):
        urllib.request.urlretrieve("http://10.0.2.2:__PORT__/" + name, "/run/headunit-build/" + name)
    PY
  # (to a file, and to the console afterwards: a login prompt that starts on the console hangs up whoever has it)
  - "bash /run/headunit-build/provision.sh /run/headunit-build > /run/headunit-build/log 2>&1; echo $? > /run/headunit-build/status"
  - "tail -n 60 /run/headunit-build/log > /dev/console"
  - "[ \"$(cat /run/headunit-build/status)\" = 0 ] && echo headunit-image-done > /dev/console || echo headunit-image-FAILED > /dev/console"
power_state:
  mode: poweroff
  timeout: 30
SEED
port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
sed -i.bak -e "s|__PORT__|$port|" "$WORK/files/user-data" && rm "$WORK/files/user-data.bak"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$WORK/files" > "$WORK/http.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null; rm -rf "$WORK"' EXIT


disk="$WORK/disk.qcow2"
qemu-img convert -O qcow2 "$CACHE/debian-13-generic-$ARCH.qcow2" "$disk"
qemu-img resize -q "$disk" "$DISK_SIZE"

accel=tcg; cpu=max
if echo "$host" | grep -qw "$(uname -m)"; then
    if [ -w /dev/kvm ]; then accel=kvm; cpu=host; elif [ "$(uname -s)" = Darwin ]; then accel=hvf; cpu=host; fi
fi
firmware=()
if [ "$ARCH" = arm64 ]; then
    code="${AARCH64_FIRMWARE:-}"
    for found in /opt/homebrew/share/qemu/edk2-aarch64-code.fd /usr/share/AAVMF/AAVMF_CODE.fd \
        /usr/share/edk2/aarch64/QEMU_EFI-pflash.raw; do
        [ -n "$code" ] || { [ -f "$found" ] && code="$found"; } || true
    done
    [ -n "$code" ] || { echo "no UEFI firmware for aarch64 found: set AARCH64_FIRMWARE" >&2; exit 1; }
    dd if=/dev/zero of="$WORK/vars.fd" bs=1048576 count=64 2>/dev/null
    firmware=(-drive "if=pflash,format=raw,readonly=on,file=$code" -drive "if=pflash,format=raw,file=$WORK/vars.fd")
fi

echo "building with $qemu ($accel); the console is $OUT/build-$ARCH.log"
"$qemu" -accel "$accel" -machine "$machine" -cpu "$cpu" -smp 4 -m 4G -display none -no-reboot \
    "${firmware[@]}" \
    -drive "if=virtio,file=$disk,format=qcow2" \
    -smbios "type=1,serial=ds=nocloud;s=http://10.0.2.2:$port/" \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -serial "file:$OUT/build-$ARCH.log"

if ! grep -q "headunit-image-done" "$OUT/build-$ARCH.log"; then
    echo "the image was not provisioned: see $OUT/build-$ARCH.log" >&2
    exit 1
fi
qemu-img convert -c -O qcow2 "$disk" "$OUT/headunit-linux-$ARCH.qcow2"
ls -lh "$OUT/headunit-linux-$ARCH.qcow2"
