#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# Builds jumpstarter-test-player.apk from the sources beside it, with the Android SDK's own tools (no Gradle):
#
#   ANDROID_HOME=~/Library/Android/sdk apps/test-player/build.sh
#
# It needs a JDK, and an SDK with a platform and build-tools. The APK is signed with a key made for the build, so a
# device that has an earlier build must uninstall it first (the suite does).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
tools=$(ls -d "$sdk"/build-tools/* | sort -V | tail -1)
platform=$(ls -d "$sdk"/platforms/android-[0-9][0-9] | sort -V | tail -1)/android.jar

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/classes" "$work/dex"

javac -source 11 -target 11 -Xlint:-options -cp "$platform" -d "$work/classes" $(find "$here/src" -name '*.java')
"$tools/d8" --lib "$platform" --min-api 29 --output "$work/dex" $(find "$work/classes" -name '*.class')
"$tools/aapt2" link -o "$work/unsigned.apk" --manifest "$here/AndroidManifest.xml" -I "$platform"
(cd "$work/dex" && zip -q "$work/unsigned.apk" classes.dex)
"$tools/zipalign" -f 4 "$work/unsigned.apk" "$work/aligned.apk"
keytool -genkeypair -keystore "$work/key.jks" -storepass android -keypass android -alias test -keyalg RSA \
  -keysize 2048 -validity 10000 -dname "CN=Jumpstarter Test Player" >/dev/null 2>&1
"$tools/apksigner" sign --ks "$work/key.jks" --ks-pass pass:android --key-pass pass:android \
  --out "$here/jumpstarter-test-player.apk" "$work/aligned.apk"
rm -f "$here/jumpstarter-test-player.apk.idsig"
ls -l "$here/jumpstarter-test-player.apk"
