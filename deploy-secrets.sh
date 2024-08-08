#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

for cmd in "istioctl" "kubectl" "jq"; do
  type $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but it's not installed; aborting."; exit 1; }
done

EAST_SERVER=$(kubectl get node --context kind-east -l node-role.kubernetes.io/control-plane -o json \
  | jq -r '.items[] | .status.addresses[] | select(.type=="InternalIP") | .address')

istioctl create-remote-secret \
  --context=kind-east \
  --server https://${EAST_SERVER}:6443 \
  --name=east | \
  kubectl apply -f - --context=kind-west

WEST_SERVER=$(kubectl get node --context kind-west -l node-role.kubernetes.io/control-plane -o json \
  | jq -r '.items[] | .status.addresses[] | select(.type=="InternalIP") | .address')

istioctl create-remote-secret \
  --context=kind-west \
  --server https://${WEST_SERVER}:6443 \
  --name=west | \
  kubectl apply -f - --context=kind-east
