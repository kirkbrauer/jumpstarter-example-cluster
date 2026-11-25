# Jumpstarter example cluster

A small device lab on a Kubernetes cluster, and tests that run against it: virtual Android phones and head units
(Cuttlefish), virtual Linux machines (QEMU), and room for a real iPhone, iPad or Android device on a bench beside
it. Everything is leased, driven and watched through [Jumpstarter](https://jumpstarter.dev).

It is an example to copy from, taken from a working lab. Read [what has been run](#what-has-been-run) before
relying on a part of it.

```
argocd/         the whole lab as Argo CD applications: one to apply, and it installs the rest
cluster/        the lab itself: the Jumpstarter operator, Jumpstarter, and the virtual devices
images/         the exporter image the virtual devices run
physical/       a real device on a bench: the exporter beside it (iOS over USB, Android over USB)
edge-gateway/   a real radio beside a real device, so that it can be tested against a virtual one
workspace/      an Eclipse Che workspace for test engineers, with the sample project
  project/      Robot Framework suites: Bluetooth pairing, calls, music, contacts, messages, a real iPad
tekton/         the same suites as an OpenShift Pipelines (Tekton) pipeline
```

## The lab

You need a cluster with [cert-manager](https://cert-manager.io) and, for Cuttlefish, at least one x86-64 node
with KVM. Fork this repository, and in the fork:

1. replace `example.com` in `cluster/jumpstarter.yaml` with your cluster's application domain;
2. build the exporter image ([`images`](images)) and name it in `cluster/devices/kustomization.yaml`.

Then, with [Argo CD](argocd):

```console
$ kubectl label node <node> jumpstarter.dev/cuttlefish=true
$ kubectl apply -n argocd -f argocd/root.yaml
```

or by hand, in the same order:

```console
$ kubectl apply -k cluster/operator
$ kubectl apply -k cluster
$ kubectl apply -k cluster/devices
```

Either way, Cuttlefish Pods have to be allowed to run privileged: `cluster/cuttlefish-runtime.yaml` says how, for
OpenShift and for other clusters. [`argocd/README.md`](argocd/README.md) has what else Argo CD leaves to you.

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

Everything is pinned to the Jumpstarter build the lab was run with (`0.10.0-dev-246`): the operator, the
controller and the image the exporter starts from. Move them together.

### The screen

The devices' live screen is a driver that is not in a Jumpstarter release yet, so the devices come without it.
`cluster/devices-with-screen` adds it, for an exporter image built with that driver: see
[`images/README.md`](images/README.md).

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
| The lab on OKD (Routes, self-signed certificates) | Yes, installed by hand | On another Kubernetes; an Ingress or Gateway in place of the Routes |
| Installing through Argo CD | No: the applications render, and no Argo CD has synced them | |
| The exporter image of `images/exporter` | Built once on that cluster, not yet run as a device | The lab's own devices run an image with the screen driver added |
| Cuttlefish phone and head unit, QEMU machine | Yes | |
| The Bluetooth suites between the two Cuttlefish devices | Yes, also in Che and as a pipeline | |
| An iPad over USB on the Pi | Yes | An iPhone; the quadlets do not tell them apart |
| The edge gateway with the iPad | Yes: Bluetooth pairing and audio, and one page over Wi-Fi | Any other controller or Wi-Fi card than the Pi 4's |
| An Android device over USB | No | The configuration is an example only |
| The files exactly as they are here | No | They were renamed and given placeholders (`example.com`, image names) for this repository |

Two things the suites depend on that a new lab will meet:

* the phone and the head unit of the Bluetooth suites are one lease, from the lease template
  `phone-and-head-unit`, and the lease joins their Bluetooth radios (its forward `bluetooth`): that needs a
  Jumpstarter with leases of several exporters and forwards between them (JEP-0015, JEP-0016), and an exporter
  image with `jumpstarter-driver-bluetooth` and `jumpstarter-driver-wifi`. Only the pairing suite has been run this way;
* the iPad and the head unit are one lease too, from `ipad-and-head-unit`, whose forwards join the real
  Bluetooth controller beside the iPad to the head unit's radio and the test Wi-Fi's port to a port inside the
  head unit: the iPad's exporter needs the same Jumpstarter and the same two packages (`physical/ios`);
* the head unit and phone are stock AOSP images, without Google services: there is no Android Auto projection.

## Licence

Apache-2.0. See [LICENSE](LICENSE).
