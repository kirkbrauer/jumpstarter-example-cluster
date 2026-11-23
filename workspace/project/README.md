# Jumpstarter test project

A starting point for Robot Framework suites that run against leased devices.

* **Jumpstarter** (the bolt in the activity bar): the lab's exporters, your leases, and a lease's drivers with the
  commands each has. A driver with a screen or an inspector has **Open View**: it opens beside the editor.
* **`tests/`**: the suites. Run one from the Testing view (RobotCode) or with
  `robot --outputdir results tests/bluetooth_pairing.robot`. A suite leases the devices it needs, or uses a lease you
  already hold for the same selector, and powers them on.
* **Agents**: the editor's chat has Jumpstarter's MCP tools and skills from the Jumpstarter extension. **Claude Code**
  (the spark in the activity bar; sign in first) reads this project's own files instead: `.mcp.json` names the same
  server (`jmp mcp serve`) and `.claude/skills` has the same skills.
* **Terminal**: `jmp get exporters`, `jmp shell --selector type=phone`, and `j` inside a lease, as on any machine.

To watch a suite run, lease its devices first and open their screens: `./lease-devices.sh` leases the phone and
the head unit of the Bluetooth suites (`--release` gives them back). A suite uses the leases you hold and leaves
them with you, so the screens you opened from the Jumpstarter view stay open from one run to the next.

Your Jumpstarter client configuration is mounted from the Secret of your Che namespace
(`~/.config/jumpstarter/clients`).

## The suites

| Suite | What it shows |
| --- | --- |
| `tests/phone.robot` | One leased phone: its drivers, and the keywords they give. |
| `tests/two_devices.robot` | Two devices in one suite, each in a session of its own. |
| `tests/bluetooth_pairing.robot` | A phone pairs with a car's head unit over Bluetooth: Jumpstarter leases both and joins their radios, Appium taps through the pairing on each, ADB checks what each then believes. |
| `tests/bluetooth_phone_call.robot` | A call with the phone paired to the car: the call the phone makes is a call on the head unit, and either can end it for both. |
| `tests/bluetooth_media.robot` | Music from the phone through the car: the head unit shows the track the phone has, and its buttons play, pause and skip on the phone. |
| `tests/bluetooth_connection.robot` | A phone and a car that know each other: either disconnects and connects again, the phone comes back by itself when the car's Bluetooth does, and the phone can forget the car. |
| `tests/bluetooth_contacts.robot` | The phone's contacts in the car, once its owner allows it: names with accents, in other scripts, written right to left, with emoji, and a very long one arrive as they are. |
| `tests/bluetooth_messages.robot` | Text messages in the car: a message that reaches the phone reaches the head unit word for word, emoji, other scripts and long ones included. |
| `tests/ipad_bluetooth.robot` | A real iPad and the virtual head unit, over real Bluetooth: they pair, and a web page's audio on the iPad plays through the head unit. |
| `tests/ipad_wifi.robot` | A real iPad, on real Wi-Fi, opens a page that the virtual head unit serves. |

## How the Bluetooth suite is put together

```
tests/bluetooth_pairing.robot      the test: one line for each thing the driver does or checks
tests/bluetooth_phone_call.robot   the same for a phone call between paired devices
resources/bluetooth.resource       those lines, as Appium presses and ADB reads
tests/bluetooth_media.robot        the same for music from the phone
resources/calls.resource           the same for calls
resources/media.resource           the same for music
tests/bluetooth_connection.robot   disconnecting, connecting again and forgetting (its keywords are in bluetooth.resource)
tests/bluetooth_contacts.robot     the phone's contacts on the head unit
resources/contacts.resource        the same for contacts
tests/bluetooth_messages.robot     the phone's text messages on the head unit
resources/messages.resource        the same for text messages
apps/test-player                   the phone's player for the music suite: its source, and the APK the suite installs
resources/devices.resource         the two devices: leasing, power, ADB and Appium on each
libraries/BluetoothBridge.py       the bridge between the two radios
```

The phone and the head unit are virtual (Cuttlefish), and each has a Bluetooth radio of its own: left alone they
cannot see each other. `Connect The Radios Of The Phone And The Head Unit` puts a bridge between them. In the phone's
radio the bridge is a device with the head unit's name; in the head unit's radio it is a device with the phone's; and
what either says to it, it says to the other. It reaches each radio through the lease (the exporter's `bluetooth`
driver).

Two things follow from that, and are worth knowing when you read a failure:

* each device pairs with the bridge, a pairing each; the suite reads the code both show and checks they are the same;
* each device knows the other by the bridge's address, not by the other's own.

What the lab provides for it: each exporter has, beside its Cuttlefish and Android drivers, one that reaches the
radio's HCI port (`netsimd --hci_port`, 7300 by default):

```yaml
bluetooth:
  type: jumpstarter_driver_network.driver.TcpNetwork
  config:
    host: 127.0.0.1
    port: 7300
```

Which devices are leased is at the top of `resources/devices.resource` (`${PHONE SELECTOR}`,
`${HEAD UNIT SELECTOR}`); override them with `--variable "PHONE SELECTOR:type=phone"`.

What a screen cannot show here is read with ADB instead, and the suites say so where it happens:

* this head unit's dialer has no keypad or call screen, and it has no contacts or messages screen: a call is dialled
  on it as a dial request, and its calls, contacts and messages are read from the device;
* the emulated phone has no network to receive a call or a text message over: a message is put in the phone's inbox,
  where its radio would put it, and there is no test of a call coming in;
* the head unit's Bluetooth must be allowed to keep the messages it receives, which a car's is and the emulator's is
  not (`Let The Head Unit Keep The Phone's Messages`).

The same suite runs unattended as a Tekton pipeline: see `tekton` in this repository.

## A physical device and a virtual one

The two `ipad_` suites test a device on a bench against a head unit that exists only in the cluster. Beside the
iPad, on its exporter's host, is an **edge gateway**: a real Bluetooth controller and a test Wi-Fi network, each
offered as a port through the iPad's lease (`edge-gateway` in this repository has them, and
how to set one up). The suites join those ports to the head unit:

```
resources/ipad.resource      the iPad: its lease, what is pressed on it (Appium, XCUITest), and the two joins
libraries/BluetoothBridge.py the same bridge as between two virtual devices: one of its radios is now real
libraries/PortRelay.py       a port of the gateway's Wi-Fi network, answered by a port inside the head unit
```

They need what the other suites do not:

* the iPad's driver in the environment that runs them (`jumpstarter-driver-iosdevice`; the workspace image does
  not have it), and WebDriverAgent running on the iPad;
* the iPad's name and Bluetooth address, given with `--variable` (see the top of each suite);
* for Wi-Fi, an iPad that already knows the test network: join it once by hand. A suite does not type a
  network's password. While it is on that network the iPad has no internet.

Over Wi-Fi the iPad reaches one port of the head unit, relayed; the two are not on one network.

## The test player

Stock Android has no music player a head unit can follow, so the music suite installs one of its own on the phone:
`apps/test-player`, an app of two source files. It has two tracks, each a tone it generates, a media session with
their titles, and a screen whose every part has an accessibility id (`Track title`, `Playback state`, `Play`,
`Pause`, `Next track`, `Previous track`). `apps/test-player/build.sh` builds the APK with the Android SDK's own
tools; the built APK is beside it, so running the suite needs no SDK.
