#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
#
# Makes a Debian 13 cloud image into the Linux head unit of the phone projection suite. It runs once, as root,
# inside the image while build.sh has it booted; FILES is where build.sh's files are mounted.
#
# What it sets up, and why each is needed, is in README.md.
set -euxo pipefail
FILES="${1:?where the files of the build are}"
USER_NAME=hu
export DEBIAN_FRONTEND=noninteractive

apt-get update -q
# LIVI's runtime (its scripts/install/packages.txt: core and lite), and what the radios need.
apt-get install -y -q --no-install-recommends \
    bluez bluez-tools libspa-0.2-bluetooth hostapd dnsmasq-base iw rfkill wireless-regdb kmod \
    pulseaudio-utils pipewire pipewire-pulse wireplumber avahi-daemon avahi-utils \
    libva2 libva-drm2 libva-x11-2 mesa-va-drivers libssh-4 libfontconfig1 libxkbcommon0 fuse3 \
    libseat1 libinput10 libgbm1 libegl1 libgles2 libwayland-client0 libwayland-cursor0 libwayland-egl1 \
    seatd xdg-user-dirs curl python3 iproute2 sudo
apt-get clean

# ---- The person at the head unit ----------------------------------------------------------------------------------
id "$USER_NAME" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$USER_NAME"
for group in video render input audio bluetooth netdev; do
    getent group "$group" >/dev/null && usermod -aG "$group" "$USER_NAME"
done
# (LIVI reaches the radios through a helper it runs with `sudo -n`; a lease's own cloud-init says the same)
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-headunit
chmod 0440 /etc/sudoers.d/90-headunit
loginctl enable-linger "$USER_NAME"

# ---- Bluetooth: the controller is at the far end of a serial port ---------------------------------------------------
# systemd puts a login prompt on a virtio console; what it prints there is not HCI.
systemctl mask serial-getty@hvc0.service
install -m 0755 "$FILES/headunit-bluetooth-attach" /usr/local/sbin/headunit-bluetooth-attach
install -m 0644 "$FILES/headunit-bluetooth.service" /etc/systemd/system/headunit-bluetooth.service

# ---- Wi-Fi: one simulated radio, and the bridge that is its medium ---------------------------------------------------
cat > /etc/modprobe.d/headunit-wifi.conf <<'CONF'
# An access point on 5 GHz needs a country.
options cfg80211 ieee80211_regdom=US
options mac80211_hwsim radios=1
CONF
echo mac80211_hwsim > /etc/modules-load.d/headunit-wifi.conf
# Every kernel's first simulated radio is 02:00:00:00:00:00: this one has an address of its own.
cat > /etc/systemd/network/10-headunit-wlan0.link <<'LINK'
[Match]
Driver=mac80211_hwsim
OriginalName=wlan0

[Link]
MACAddress=02:51:00:00:00:01
LINK
install -D -m 0644 "$FILES/wmediumd_agent.py" /usr/local/lib/headunit/wmediumd_agent.py
install -m 0644 "$FILES/headunit-wifi-bridge.service" /etc/systemd/system/headunit-wifi-bridge.service

# ---- LIVI, as its own installer sets it up on a host without a desktop ----------------------------------------------
install -d -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/LIVI"
install -m 0755 -o "$USER_NAME" -g "$USER_NAME" "$FILES/LIVI.AppImage" "/home/$USER_NAME/LIVI/LIVI.AppImage"
printf 'auth      required  pam_permit.so\n@include  common-account\n@include  common-session\n' > /etc/pam.d/livi-kiosk
install -m 0644 "$FILES/livi-kiosk.service" /etc/systemd/system/livi-kiosk.service

systemctl enable seatd.service bluetooth.service headunit-bluetooth.service headunit-wifi-bridge.service \
    livi-kiosk.service

# ---- A lease starts from here -----------------------------------------------------------------------------------
# The device's own cloud-init data (its host name, and this user's password) is applied on its first boot.
cloud-init clean --logs --seed
rm -f /etc/ssh/ssh_host_*
truncate -s 0 /etc/machine-id
