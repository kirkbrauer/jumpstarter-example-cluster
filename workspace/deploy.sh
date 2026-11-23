#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
#
# Starts a Jumpstarter test workspace for one Che user.
#
#   workspace/deploy.sh <che user> <client config.yaml> <image> [code|web]
#
# `code` (the default) is VS Code with the Jumpstarter extension (devworkspace.yaml); `web` is Jumpstarter Web
# itself as the workspace's editor (devworkspace-web.yaml). Both use the same image.
#
# It prepares the user's Che namespace (`<user>-che`, as Che itself would at the user's first login), mounts the
# Jumpstarter client configuration into every workspace of that namespace as a Secret, takes the che-code editor
# definition from the cluster's Che, and creates the workspace. Needs `oc`, logged in as someone who may do that.
# CHE_NAMESPACE is where the CheCluster is (default eclipse-che).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
user=$1
client=$2
image=$3
che=${CHE_NAMESPACE:-eclipse-che}
namespace="$user-che"
alias=$(basename "$client" .yaml)

oc get namespace "$namespace" >/dev/null 2>&1 || oc create namespace "$namespace"
oc label namespace "$namespace" --overwrite \
  app.kubernetes.io/part-of=che.eclipse.org app.kubernetes.io/component=workspaces-namespace
oc annotate namespace "$namespace" --overwrite "che.eclipse.org/username=$user"

# the client configuration: mounted read-only in every workspace, which copies it to where `jmp` keeps its
# configurations when it starts (devworkspace.yaml): that directory has to be the user's to write
oc -n "$namespace" create secret generic jumpstarter-client --dry-run=client -o yaml \
  --from-file="$alias.yaml=$client" | oc apply -f -
oc -n "$namespace" label secret jumpstarter-client --overwrite \
  controller.devfile.io/mount-to-devworkspace=true controller.devfile.io/watch-secret=true
oc -n "$namespace" annotate secret jumpstarter-client --overwrite \
  controller.devfile.io/mount-path=/etc/jumpstarter/clients controller.devfile.io/mount-as=file

# The che-code editor definition of this Che is a devfile: its commands, components and events are the template's
# (its other keys, the devfile's own metadata, are not the template's and are dropped by the server).
{
  printf 'apiVersion: workspace.devfile.io/v1alpha2\nkind: DevWorkspaceTemplate\nmetadata:\n  name: che-code\nspec:\n'
  oc -n "$che" get configmap editors-definitions -o 'jsonpath={.data.che-code-latest\.yaml}' | sed 's/^/  /'
} | oc -n "$namespace" apply --validate=ignore -f -

# The addresses Che gives the workspace's endpoints (`<user>-<workspace>-<endpoint>.<ingress domain>`), and the
# origin the editor, and so its panels, are served from.
domain=$(oc get ingresses.config.openshift.io cluster -o 'jsonpath={.spec.domain}')
editor=$(oc -n "$che" get checluster -o 'jsonpath={.items[0].status.cheURL}')
endpoints=""
for n in 1 2 3; do
  endpoints="$endpoints${endpoints:+,}707$n=https://$user-jumpstarter-tests-jmp-web-$n.$domain"
done

if [ "${4:-code}" = web ]; then
  # Jumpstarter Web as the editor: behind the workspace's gateway, at the path Che gives the workspace's endpoint
  sed -e "s#@WORKSPACE_IMAGE@#$image#g" -e "s#@CHE_URL@#$editor#" -e "s#@EDITOR_PATH@#/$user/jumpstarter-web/7070#" \
    "$here/devworkspace-web.yaml" | oc -n "$namespace" apply -f -
  oc -n "$namespace" get devworkspace jumpstarter-web
  exit 0
fi

sed -e "s#@WORKSPACE_IMAGE@#$image#" -e "s#@WEB_ENDPOINTS@#$endpoints#" -e "s#@FRAME_ORIGINS@#$editor#" -e "s#@CHE_URL@#$editor#g" \
  "$here/devworkspace.yaml" | oc -n "$namespace" apply -f -
oc -n "$namespace" get devworkspace jumpstarter-tests
