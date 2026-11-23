# Images

| Image | For | Builds from this repository |
| --- | --- | --- |
| [`exporter`](exporter) | The virtual devices of `cluster/devices`: Jumpstarter's exporter image with Appium | Yes |
| [`../workspace`](../workspace) | The Eclipse Che workspace and the Tekton pipeline | With Jumpstarter Web wheels and the VS Code extension you give it |
| [`exporter-ios`](exporter-ios) | An iPhone or iPad on a bench (`physical/ios`) | No: kept as the lab built it, for reference |

```console
$ podman build -t registry.example.com/jumpstarter/exporter:1 images/exporter
$ podman push registry.example.com/jumpstarter/exporter:1
```

then name it in `cluster/devices/kustomization.yaml`. The `Images` workflow of this repository does the same
to the GitHub container registry, when it is run by hand.

## The screen

The devices' live screen (the `hmi` driver) is not in a Jumpstarter release yet. `cluster/devices` therefore
does without it, and `cluster/devices-with-screen` adds it for an exporter image built with the drivers that
have it:

```console
$ podman build --build-arg JUMPSTARTER_REF=<a ref that has the hmi driver> \
    --build-arg JUMPSTARTER_PACKAGES="jumpstarter-driver-cuttlefish jumpstarter-driver-qemu jumpstarter-driver-hmi" \
    -t registry.example.com/jumpstarter/exporter:1-screen images/exporter
```

The lab this comes from runs such an image, built from a branch that is not public yet.
