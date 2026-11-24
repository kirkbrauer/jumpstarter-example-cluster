#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Fetch the two open-source apps of the phone projection suite (tests/phone_projection.robot), each from its
# own project's release page, and check it against the checksum written here.
#
#   AARE           the phone's side: the Android Auto protocol without Google's app (GPL-3.0-or-later)
#                  https://github.com/prototux/AARE
#   Open Headunit  the car's side: a receiver app for a head unit (AGPL-3.0)
#                  https://github.com/andreknieriem/open-headunit
#
# The apps are not kept in this repository: they are downloaded beside this script, and git ignores them.
# To move to a newer release, change its version and checksum here, and run the suite.
set -euo pipefail
cd "$(dirname "$0")"

sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

fetch() { # name url sha256
    if [ -f "$1" ] && echo "$3  $1" | sha256 -c - >/dev/null 2>&1; then
        echo "have $1"
        return
    fi
    echo "fetching $1"
    curl --fail --location --silent --show-error --output "$1.part" "$2"
    echo "$3  $1.part" | sha256 -c - >/dev/null || { rm -f "$1.part"; echo "checksum of $1 is not the one expected" >&2; exit 1; }
    mv "$1.part" "$1"
}

fetch aare.apk \
    https://github.com/prototux/AARE/releases/download/v1.6.0/aare-1.6.0.apk \
    75d5a6778980bdc34f3545f984396ad9b591cc22909a3e0e22e0cc8e9ec4f281
fetch open-headunit.apk \
    https://github.com/andreknieriem/open-headunit/releases/download/v.4.0.0/com.andrerinas.headunitrevived_4.0.0.apk \
    5e6ac16c528d06a26b6ce764cf56a6e26dc72b70d45a4df1e64239c74e0db908
