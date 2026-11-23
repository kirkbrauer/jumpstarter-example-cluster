# Installing with Argo CD

One application installs the lab; Argo CD keeps it as this repository says.

```console
$ kubectl apply -n argocd -f argocd/root.yaml
```

| Application | Wave | What it installs | From |
| --- | --- | --- | --- |
| `jumpstarter-example-operator` | 0 | The Jumpstarter operator and its resource definitions | `cluster/operator` |
| `jumpstarter-example-lab` | 1 | The namespace, Jumpstarter itself, the Cuttlefish runtime account | `cluster` |
| `jumpstarter-example-devices` | 2 | The virtual phone, head unit and Linux machine | `cluster/devices` |
| `jumpstarter-example-pipeline` | 3 | The Tekton pipeline for the suites (off until you add it to `apps/kustomization.yaml`) | `tekton` |

Later applications use resource kinds that earlier ones define, so each retries until those are there.

## Before the first sync

In a fork of this repository (the applications read from the repository they name):

1. **Your domain.** Replace `example.com` in `cluster/jumpstarter.yaml`. As written the endpoints are OpenShift
   Routes; on another Kubernetes, expose them your cluster's way.
2. **Your exporter image.** Build `images/exporter`, and name it in `cluster/devices/kustomization.yaml`.
3. **The repository.** Change `repoURL` in `argocd/root.yaml` and `argocd/apps/*.yaml` to your fork.

## What Argo CD does not do here

- **cert-manager** has to be installed already: Jumpstarter asks it for its certificates.
- **The nodes for Cuttlefish**: label the ones that have KVM, `jumpstarter.dev/cuttlefish=true`.
- **Privileged Pods for Cuttlefish.** On OpenShift and OKD, once:
  `oc adm policy add-scc-to-user privileged -n jumpstarter-lab -z cuttlefish-runtime`. Elsewhere, let the
  namespace run privileged Pods (see `cluster/cuttlefish-runtime.yaml`).
- **Argo CD's own rights.** Its application controller has to be allowed to manage the namespaces and the
  cluster-wide resources above. OpenShift GitOps is not, by default, for namespaces it did not make.
- **Images, clients, real devices.** Building images (`images`), making a client (`jmp admin create client`),
  and a device on a bench (`physical`, `edge-gateway`) are done by hand.

These applications have been checked to render; they have **not been synced by an Argo CD** yet. The lab they
describe was installed by hand, with the same manifests before they were given placeholders.
