# The Linux head unit's disk image

The head unit of `workspace/project/tests/phone_projection_linux.robot`: Debian 13 in QEMU, with
[LIVI](https://github.com/f-io/LIVI) as the receiver a phone projects to, on BlueZ and hostapd. It has no radio
hardware and no radio simulator of its own; a lease joins its Bluetooth and its Wi-Fi to a phone's
(`cluster/devices-linux-headunit`).

```console
$ WMEDIUMD_AGENT=<jumpstarter>/python/packages/jumpstarter-driver-wifi/jumpstarter_driver_wifi/wmediumd_agent.py \
    ./build.sh amd64
…
out/headunit-linux-amd64.qcow2
```

`build.sh` boots Debian's cloud image once in QEMU, with `provision.sh` as what it does on its first boot, and
keeps the disk as it is when that has powered off. `amd64` is what the lab's QEMU devices are; `arm64` builds
the same for an ARM machine. On a machine of the image's own architecture (KVM, or HVF on a Mac) it takes a few
minutes; emulated, much longer.

## What is in it

| | What | Why |
| --- | --- | --- |
| Bluetooth | `headunit-bluetooth.service`: `btattach -B /dev/hvc0 -P h4`, again until `hci0` is up | The controller is at the far end of a serial port of the guest (the QEMU driver's `serial_ports`). `btattach` sets a controller up once, when it starts: started while the phone that has the controller is still off, the kernel gives the adapter up |
| | `serial-getty@hvc0` masked | systemd puts a login prompt on a virtio console, and what it prints there is not HCI |
| Wi-Fi | `mac80211_hwsim`, one radio, country `US` | A simulated radio of the kernel's own. Without a country no access point is allowed on 5 GHz |
| | `wlan0` is `02:51:00:00:00:01` | Every kernel's first simulated radio is `02:00:00:00:00:00`, and so is every Cuttlefish device's access point: two radios with one address must not meet on one air |
| | `headunit-wifi-bridge.service`: `wmediumd_agent.py --hwsim --listen 0.0.0.0:7310` | The frame bridge of `jumpstarter-driver-wifi`, as the radio's medium. Its port leaves the guest as a forwarded port, and the exporter's `wifi` driver has it |
| LIVI | `livi-kiosk.service`, as user `hu`, with `LIVI_GST_SWDEC=1` | LIVI's own kiosk unit. A virtual GPU has no video decoder |
| The user | `hu`, in the groups LIVI needs, with `sudo` | LIVI reaches the radios through a helper it runs with `sudo -n` |

Wireless Android Auto is one of LIVI's settings (`~/.config/LIVI/config.json`, written when LIVI first runs).
The suite switches it on.

The image is left as a cloud image that has not booted: a device's own cloud-init data (its host name, and the
password of `hu`) is applied when a lease first powers it on.

## Trying it, from an Eclipse Che workspace

1. **An exporter image with the drivers.** The QEMU driver's `serial_ports`, the Bluetooth driver's
   `guest_listens` and the Wi-Fi driver's `external` are not in a Jumpstarter release yet:

   ```console
   $ podman build --build-arg JUMPSTARTER_REF=<a ref that has them> \
       -t registry.example.com/jumpstarter/exporter:linux-headunit ../exporter
   $ podman push registry.example.com/jumpstarter/exporter:linux-headunit
   ```

   and name it for the `qemu-x86-64` and `cf-phone` classes (`cluster/devices/kustomization.yaml`).

2. **This image, where the head unit's exporter can fetch it**: any web server the cluster reaches, or a
   registry (`oci://…`).

3. **The devices and their lease template:**

   ```console
   $ kubectl apply -f cluster/devices-linux-headunit/linux-headunit.yaml
   $ kubectl apply -k cluster/templates          # phone-and-linux-head-unit, with the others
   $ jmp get lease-templates
   ```

4. **The suite**, in the workspace's terminal or from its Testing view (set the variables in `robot.toml` there):

   ```console
   $ cd workspace/project
   $ robot --outputdir results \
       --variable "HEAD UNIT IMAGE:https://<where the image is>/headunit-linux-amd64.qcow2" \
       --variable "HEAD UNIT SHELL:console" \
       tests/phone_projection_linux.robot
   ```

   `HEAD UNIT SHELL:console` types on the head unit's serial console. The default, `ssh`, needs an `ssh` driver
   on the head unit's exporter, which an ExporterSet cannot declare yet (see the manifest).

To look at the head unit by hand, lease the pair and open a shell: `jmp shell --lease-template
phone-and-linux-head-unit`, then `j headunit qemu flasher flash <image>`, `j phone cuttlefish power on`,
`j headunit qemu power on`, and `j headunit qemu console`.

## What has been tried

The image boots in QEMU on an ARM Mac, LIVI draws its screen on the virtual GPU, registers its Android Auto
service with BlueZ over the serial port, and keeps its access point on the simulated radio; a station on another
simulated air joined that network through two frame bridges. A phone has not projected to it yet: that is the
suite's first run in the lab.
