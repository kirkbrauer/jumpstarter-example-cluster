# Edge gateways: a physical device and a virtual one

A phone or tablet on a bench has real radios; a virtual head unit has simulated ones. An **edge gateway** is a
radio on the exporter host beside the physical device, offered as a port through that exporter's lease. Joined
to a virtual device, it puts the virtual device on real air:

```text
 physical device ))) real radio ── gateway ── exporter ══ lease ══ test ══ lease ══ exporter ── virtual device
                     └────────── the host beside the device ─────────┘
```

Two gateways are here, both one file of standard-library Python, run as Podman quadlets:

| Gateway | The port it offers | What crosses it |
| --- | --- | --- |
| `hci_gateway.py` | `127.0.0.1:7300`: the host's Bluetooth controller, as HCI packets in H4 framing | A Bluetooth host on the other end is on the air through this controller |
| `wifi_gateway.py` | `10.77.0.1:8080` on a test Wi-Fi network, answered by whoever attaches at `127.0.0.1:7410` | One TCP port: a device on the Wi-Fi that connects to it is talking to the far end |

What joins a gateway's port to a virtual device is, for now, the test itself (`libraries/BluetoothBridge.py` and
`libraries/PortRelay.py` in the sample project). They are stand-ins for the inter-exporter forwards of
JEP-0015, where the test is no longer in the path.

The Wi-Fi gateway joins at the level of a connection: the physical device reaches one port of the virtual one.
It does not put the two on one network segment.

## Bluetooth

The gateway takes the controller for itself, so the host's own Bluetooth service must not be using it.

```console
# install -d /etc/jumpstarter/bt-gateway
# install -m 644 hci_gateway.py /etc/jumpstarter/bt-gateway/
# install -m 644 jumpstarter-bt-gateway.container /etc/containers/systemd/
# systemctl daemon-reload && systemctl start jumpstarter-bt-gateway
```

Give each gateway an address of its own (`--address` in the quadlet): the devices that pair know it by that.
Then offer the port from the exporter beside it:

```yaml
export:
  bluetooth:
    type: jumpstarter_driver_network.driver.TcpNetwork
    config:
      host: 127.0.0.1
      port: 7300
```

## Wi-Fi

A test network on the host's Wi-Fi card, cut off from everything but the gateway: no route to the LAN or the
internet, and a firewall zone that allows address assignment and the one port.

```console
# firewall-cmd --permanent --new-zone=jumpstarter-test
# firewall-cmd --permanent --zone=jumpstarter-test --add-service=dhcp --add-port=8080/tcp
# firewall-cmd --reload
# nmcli con add type wifi ifname wlan0 con-name jumpstarter-test-ap autoconnect no ssid JumpstarterBench \
    802-11-wireless.mode ap 802-11-wireless.band bg 802-11-wireless.channel 6 \
    ipv4.method manual ipv4.addresses 10.77.0.1/24 ipv6.method disabled connection.zone jumpstarter-test \
    wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$(head -c 15 /dev/urandom | base64 | tr -d '/+=')"
# nmcli con up jumpstarter-test-ap
# install -d /etc/jumpstarter/wifi-gateway
# install -m 644 wifi_gateway.py /etc/jumpstarter/wifi-gateway/
# install -m 644 jumpstarter-wifi-gateway.container /etc/containers/systemd/
# systemctl daemon-reload && systemctl start jumpstarter-wifi-gateway
```

```yaml
export:
  wifi:
    type: jumpstarter_driver_network.driver.TcpNetwork
    config:
      host: 127.0.0.1
      port: 7410
```

Join the physical device to the network once, by hand: `nmcli -s -g 802-11-wireless-security.psk con show
jumpstarter-test-ap` prints the passphrase. The device then remembers the network, and a suite selects it from
the saved ones. A device on it has no internet.

## Taking it away

```console
# systemctl stop jumpstarter-bt-gateway jumpstarter-wifi-gateway
# rm -r /etc/containers/systemd/jumpstarter-{bt,wifi}-gateway.container /etc/jumpstarter/{bt,wifi}-gateway
# systemctl daemon-reload
# nmcli con delete jumpstarter-test-ap
# firewall-cmd --permanent --delete-zone=jumpstarter-test && firewall-cmd --reload
```

and remove the `bluetooth` and `wifi` entries from the exporter's configuration.

## What was tried with it

An iPad on a Raspberry Pi 4 (the Pi's built-in controller and Wi-Fi card), and a Cuttlefish head unit in a
cluster: the iPad paired with the head unit, played a web page's audio through it, and opened a page the head
unit served. The suites are `tests/ipad_bluetooth.robot` and `tests/ipad_wifi.robot` in the sample project.
