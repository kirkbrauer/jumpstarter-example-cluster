# The test engineer's workspace

An image for an [Eclipse Che](https://eclipse.dev/che/) workspace: VS Code with the Jumpstarter extension and
RobotCode, Jumpstarter and Robot Framework, and the sample project in [`project`](project). The Tekton pipeline in
[`../tekton`](../tekton) runs its suites from the same image.

| File | What it is for |
| --- | --- |
| `Containerfile`, `build.sh` | The image, built on the cluster: `workspace/build.sh <wheels dir> <vscode-jumpstarter.vsix> <image>`. The wheels are the Jumpstarter packages that are not on an index yet. |
| `devworkspace.yaml`, `deploy.sh` | A workspace for one Che user, with their Jumpstarter client configuration mounted from a Secret: `workspace/deploy.sh <che user> <client config.yaml> <image>`. |
| `devworkspace-web.yaml` | The same workspace with Jumpstarter Web as its editor (`deploy.sh ... web`). |
| `jumpstarter.code-workspace` | What the editor opens. |

Each script says at its top what it needs.
