#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Lease the phone and the head unit of the Bluetooth suites, together in one lease, and keep them.
#
#   ./lease-devices.sh             lease both for 2 hours (a lease you already hold is kept as it is)
#   ./lease-devices.sh 4h          the same, for 4 hours
#   ./lease-devices.sh --release   give them back
#
# A suite uses a lease you already hold from its lease template, and leaves it with you when it ends. So with
# the devices leased here, their screens stay open in the Jumpstarter view from one run to the next.
#
# The lease template is that of `resources/devices.resource`; to lease from another, set it for both:
#
#   LEASE_TEMPLATE=my-phone-and-head-unit ./lease-devices.sh
#   robot --variable "LEASE TEMPLATE:my-phone-and-head-unit" tests/...
set -euo pipefail

LEASE_TEMPLATE="${LEASE_TEMPLATE:-phone-and-head-unit}"

# The names of the leases this client holds from a lease template, one on a line.
held() {
    jmp get leases -o json | python3 -c '
import json, sys
for lease in json.load(sys.stdin).get("leases") or []:
    if (lease.get("template") or {}).get("template") == sys.argv[1]:
        print(lease["name"])
' "$1"
}

case "${1:-}" in
    -h | --help)
        sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    --release)
        for name in $(held "$LEASE_TEMPLATE"); do
            jmp delete leases "$name" >/dev/null
            echo "released $name"
        done
        ;;
    *)
        name="$(held "$LEASE_TEMPLATE" | head -n 1)"
        if [ -n "$name" ]; then
            echo "already leased ($LEASE_TEMPLATE): $name"
        else
            echo "leasing $LEASE_TEMPLATE for ${1:-2h} ..."
            name="$(jmp create lease --lease-template "$LEASE_TEMPLATE" --duration "${1:-2h}" -o name)"
            echo "$name"
        fi
        echo
        echo "Open their screens: Jumpstarter view > Leases > the lease > a device's screen > Open View."
        echo "Then run a suite: robot --outputdir results tests/bluetooth_pairing.robot"
        ;;
esac
