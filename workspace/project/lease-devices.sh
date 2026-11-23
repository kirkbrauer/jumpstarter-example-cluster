#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Lease the phone and the head unit of the Bluetooth suites, and keep them.
#
#   ./lease-devices.sh             lease both for 2 hours (a lease you already hold is kept as it is)
#   ./lease-devices.sh 4h          the same, for 4 hours
#   ./lease-devices.sh --release   give both back
#
# A suite uses a lease you already hold for its selector, and leaves it with you when it ends. So with the
# devices leased here, their screens stay open in the Jumpstarter view from one run to the next.
#
# The selectors are those of `resources/devices.resource`; to lease other devices, set them for both:
#
#   PHONE_SELECTOR=type=phone HEAD_UNIT_SELECTOR=type=head-unit ./lease-devices.sh
#   robot --variable "PHONE SELECTOR:type=phone" --variable "HEAD UNIT SELECTOR:type=head-unit" tests/...
set -euo pipefail

PHONE_SELECTOR="${PHONE_SELECTOR:-device=cf-phone}"
HEAD_UNIT_SELECTOR="${HEAD_UNIT_SELECTOR:-device=cf-headunit}"

# The names of the leases this client holds for a selector, one on a line.
held() {
    jmp get leases -o json | python3 -c '
import json, sys
for lease in json.load(sys.stdin).get("leases") or []:
    if lease.get("selector") == sys.argv[1]:
        print(lease["name"])
' "$1"
}

lease() {
    local device="$1" selector="$2" duration="$3" name
    name="$(held "$selector" | head -n 1)"
    if [ -n "$name" ]; then
        echo "$device: already leased ($selector): $name"
        return
    fi
    echo "$device: leasing $selector for $duration ..."
    name="$(jmp create lease --selector "$selector" --duration "$duration" -o name)"
    echo "$device: $name"
}

release() {
    local device="$1" selector="$2" name
    for name in $(held "$selector"); do
        jmp delete leases "$name" >/dev/null
        echo "$device: released $name"
    done
}

case "${1:-}" in
    -h | --help)
        sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    --release)
        release "phone" "$PHONE_SELECTOR"
        release "head unit" "$HEAD_UNIT_SELECTOR"
        ;;
    *)
        lease "phone" "$PHONE_SELECTOR" "${1:-2h}"
        lease "head unit" "$HEAD_UNIT_SELECTOR" "${1:-2h}"
        echo
        echo "Open their screens: Jumpstarter view > Leases > a lease > its screen > Open View."
        echo "Then run a suite: robot --outputdir results tests/bluetooth_pairing.robot"
        ;;
esac
