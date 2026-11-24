# A Robot Framework suite as a Tekton pipeline

The suites a test engineer runs in the Che workspace ([workspace](../workspace)) also run unattended:
the same suite, from the same image. A suite leases its devices itself, powers them on and releases them, so the
pipeline is one task that runs `robot`.

| File | What it is |
| --- | --- |
| `robot-suite.yaml` | The task `jumpstarter-robot` (run a suite with a Jumpstarter client configuration) and the pipeline `jumpstarter-robot-suite` around it. |
| `run-bluetooth-pairing.yaml` | One run: the Bluetooth pairing suite (`tests/bluetooth_pairing.robot`). |
| `run-bluetooth-phone-call.yaml` | One run: the phone call suite (`tests/bluetooth_phone_call.robot`). |
| `run-bluetooth-media.yaml` | One run: the music suite (`tests/bluetooth_media.robot`). |
| `run-bluetooth-connection.yaml` | One run: the connection suite (`tests/bluetooth_connection.robot`). |
| `run-bluetooth-contacts.yaml` | One run: the contacts suite (`tests/bluetooth_contacts.robot`). |
| `run-bluetooth-messages.yaml` | One run: the text message suite (`tests/bluetooth_messages.robot`). |

```console
$ oc -n my-tests create secret generic jumpstarter-client --from-file=my-client.yaml
$ oc -n my-tests apply -f tekton/robot-suite.yaml
$ oc -n my-tests create -f tekton/run-bluetooth-pairing.yaml
$ tkn -n my-tests pipelinerun logs --last -f
```

* **The client configuration** is a Secret with one `<name>.yaml`, as `jmp config client` writes it. The run leases
  with that client: a lease the same client already holds for the same selector is used and kept.
* **The image** is the workspace's tools image; `image` in the run names its tag. A project of your own goes in a
  workspace of the task, with `project` pointing at it.
* **The reports** (`log.html`, `report.html`, `output.xml`, `xunit.xml`) are written to the `results` workspace. The
  example run uses an `emptyDir`, which lasts as long as the run's pod; give it a `volumeClaimTemplate` to keep them.
  The pipeline's `summary` result is Robot Framework's own last line (`1 test, 1 passed, 0 failed`).
* **Other suites**: `suite` is a path in the project (`tests` runs them all), and `arguments` are passed to `robot`,
  for example `["--variable", "LEASE TEMPLATE:my-phone-and-head-unit"]`.
