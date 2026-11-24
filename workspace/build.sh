#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# Builds the workspace image on an OpenShift cluster (a binary Docker build, so nothing has to be pushed from this
# machine and the image is built for the cluster's architecture).
#
#   workspace/build.sh <wheels dir> <vscode-jumpstarter.vsix> <image>
#
# <wheels dir> holds the wheels that are not on an index: the Jumpstarter packages, jumpstarter-web and its
# plugins (`uv build --wheel`, after `scripts/build-ui.sh`). <image> is where the cluster pushes the result, e.g.
# registry.example.com/jumpstarter/che-workspace:1. Needs `oc`, logged in, with a project to build in
# (BUILD_NAMESPACE, default: the current one).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
wheels=$1
vsix=$2
image=$3

context=$(mktemp -d)
trap 'rm -rf "$context"' EXIT
mkdir -p "$context/wheels" "$context/extensions"
cp "$wheels"/*.whl "$context/wheels/"
cp "$vsix" "$context/extensions/vscode-jumpstarter.vsix"
cp "$here/Containerfile" "$context/Dockerfile"
cp -R "$here/project" "$context/project"
# (the projection suite fetches its two apps when it runs: they are other projects' work, and not put in the image)
rm -f "$context"/project/apps/projection/*.apk "$context"/project/apps/projection/*.part

# For Claude Code in the sample project: the skills of the Jumpstarter extension's agent plugin (one source: the
# VSIX), beside the project's .mcp.json. Claude Code keeps a configuration of its own and reads neither the editor's
# MCP registry nor the skills an extension contributes.
if unzip -Z1 "$vsix" | grep -q '^extension/agent-plugin/skills/'; then
  skills=$(mktemp -d)
  unzip -q "$vsix" 'extension/agent-plugin/skills/*' -d "$skills"
  mkdir -p "$context/project/.claude"
  cp -R "$skills/extension/agent-plugin/skills" "$context/project/.claude/skills"
  rm -rf "$skills"
fi

# The Claude Code extension, from Open VSX (its Linux build carries its own runtime). CLAUDE_CODE=0 leaves it out;
# CLAUDE_CODE_VERSION pins it (the latest otherwise).
if [ "${CLAUDE_CODE:-1}" != 0 ]; then
  api=https://open-vsx.org/api/Anthropic/claude-code
  version=${CLAUDE_CODE_VERSION:-$(curl -fsSL "$api" | sed -n 's/.*"version" *: *"\([^"]*\)".*/\1/p' | head -1)}
  echo "Claude Code $version"
  curl -fSL --retry 3 -o "$context/extensions/claude-code.vsix" \
    "$api/linux-x64/$version/file/Anthropic.claude-code-$version@linux-x64.vsix"
fi
cp "$here/jumpstarter.code-workspace" "$context/"

namespace=${BUILD_NAMESPACE:-$(oc project -q)}
oc -n "$namespace" get buildconfig jumpstarter-che-workspace >/dev/null 2>&1 \
  || oc -n "$namespace" new-build --name jumpstarter-che-workspace --binary --strategy docker --to-docker --to "$image"
oc -n "$namespace" patch buildconfig jumpstarter-che-workspace --type merge \
  -p "{\"spec\":{\"output\":{\"to\":{\"kind\":\"DockerImage\",\"name\":\"$image\"}}}}"
oc -n "$namespace" start-build jumpstarter-che-workspace --from-dir "$context" --follow --wait
