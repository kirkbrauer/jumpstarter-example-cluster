# Jumpstarter example cluster

A small device lab on a Kubernetes cluster, and tests that run against it: virtual Android phones and head units
(Cuttlefish), virtual Linux machines (QEMU), and room for a real iPhone, iPad or Android device on a bench beside
it. Everything is leased, driven and watched through [Jumpstarter](https://jumpstarter.dev).

It is an example to copy from, taken from a working lab. Read [what has been run](#what-has-been-run) before
relying on a part of it.

```
cluster/        the lab itself: Jumpstarter through its operator, and the virtual devices
physical/       a real device on a bench: the exporter beside it (iOS over USB, Android over USB)
edge-gateway/   a real radio beside a real device, so that it can be tested against a virtual one
workspace/      an Eclipse Che workspace for test engineers, with the sample project
  project/      Robot Framework suites: Bluetooth pairing, calls, music, contacts, messages, a real iPad
tekton/         the same suites as an OpenShift Pipelines (Tekton) pipeline
```

## The lab

You need a cluster with [cert-manager](https://cert-manager.io) and the Jumpstarter operator installed, and, for
Cuttlefish, at least one x86-64 node with KVM.

```console
$ kubectl create namespace jumpstarter-lab
$ kubectl apply -f cluster/jumpstarter.yaml            # after replacing example.com with your domain
$ kubectl label node <node> jumpstarter.dev/cuttlefish=true
$ kubectl apply -f cluster/cuttlefish-runtime.yaml     # and the step for your cluster written in that file
$ kubectl apply -f cluster/devices/
```

| File | What you get | Leased with |
| --- | --- | --- |
| `cluster/devices/cuttlefish-phone.yaml` | An Android phone | `device=cf-phone`, `type=phone` |
| `cluster/devices/cuttlefish-headunit.yaml` | An Android Automotive head unit | `device=cf-headunit`, `type=head-unit` |
| `cluster/devices/qemu-linux.yaml` | A Linux machine, up to four at once | `device=qemu-linux`, `type=linux` |

A device is made when it is leased (or kept ready), and made anew after each lease. The phone asks for 6 GiB of
memory and the head unit for 10 GiB.

Then a client, and a first lease:

```console
$ jmp admin create client me -n jumpstarter-lab --save
$ jmp get exporters
$ jmp shell --selector type=phone
```

### The images

The device definitions name `registry.example.com/jumpstarter/exporter`: an exporter image with the drivers they
list (Cuttlefish, ADB with Appium, netsim, QEMU, the screen). The lab this comes from builds that image itself,
from development branches of Jumpstarter, and **its build is not in this repository yet**. Until it is, build
one from the Jumpstarter repository's exporter image and add the drivers a definition names.

## A real device beside it

A device on a bench is served by an exporter on the host it is plugged into; that host only has to reach the
cluster's Jumpstarter endpoints.

* [`physical/ios`](physical/ios): an iPhone or iPad over USB, as Podman quadlets (a `usbmuxd` and one exporter for
  each USB port), with the screen and Appium. `exporter.example.yaml` is its configuration.
* [`physical/android`](physical/android): an Android device over USB, as an exporter configuration.
* [`edge-gateway`](edge-gateway): a real Bluetooth controller and a test Wi-Fi network on that host, each offered
  through the device's lease, to pair a real device with a virtual head unit and to let it reach one over Wi-Fi.

## The tests

[`workspace/project`](workspace/project) is a Robot Framework project. Each suite leases the devices it needs,
powers them on, and reads like what a person would do:

```robotframework
The Phone Pairs With The Head Unit
    Connect The Radios Of The Phone And The Head Unit
    Open Bluetooth Settings On The Phone
    Open Bluetooth Settings On The Head Unit
    Look For New Devices On The Head Unit
    Choose The Phone On The Head Unit
    Pairing Codes Should Match On The Head Unit And The Phone
    Confirm The Pairing On The Head Unit
    Confirm The Pairing On The Phone
```

Its [README](workspace/project/README.md) has the suites and how the Bluetooth between two virtual devices
works. Run one where the project and a Jumpstarter client configuration are:

```console
$ robot --outputdir results tests/bluetooth_pairing.robot
```

or from an editor: [`workspace`](workspace) builds an Eclipse Che workspace image with the project, RobotCode and
the Jumpstarter extension, and [`tekton`](tekton) runs the same suites unattended.

## What has been run

All of it comes from one lab: a single-node OKD cluster, a Raspberry Pi 4 beside it, and an iPad.

| Part | Run there | Not run |
| --- | --- | --- |
| The lab on OKD (Routes, self-signed certificates) | Yes | On another Kubernetes; an Ingress or Gateway in place of the Routes |
| Cuttlefish phone and head unit, QEMU machine | Yes | |
| The Bluetooth suites between the two Cuttlefish devices | Yes, also in Che and as a pipeline | |
| An iPad over USB on the Pi | Yes | An iPhone; the quadlets do not tell them apart |
| The edge gateway with the iPad | Yes: Bluetooth pairing and audio, and one page over Wi-Fi | Any other controller or Wi-Fi card than the Pi 4's |
| An Android device over USB | No | The configuration is an example only |
| The files exactly as they are here | No | They were renamed and given placeholders (`example.com`, image names) for this repository |

Two things the suites depend on that a new lab will meet:

* the Bluetooth and Wi-Fi joins are made by the test itself (`libraries/BluetoothBridge.py`,
  `libraries/PortRelay.py`). They stand in for Jumpstarter's planned inter-exporter forwards (JEP-0015);
* the head unit and phone are stock AOSP images, without Google services: there is no Android Auto projection.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
