#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

type istioctl >/dev/null 2>&1 || { echo >&2 "istioctl required but it's not installed; aborting."; exit 1; }

export CTX_CLUSTER1="kind-east"
export CTX_CLUSTER2="kind-west"

EAST_SERVER=$(kubectl get node --context kind-east -l node-role.kubernetes.io/control-plane -o json \
  | jq -r '.items[] | .status.addresses[] | select(.type=="InternalIP") | .address')

istioctl create-remote-secret \
  --context="kind-east" \
  --server ${EAST_SERVER} \
  --name=east | \
  kubectl apply -f - --context="kind-west"

WEST_SERVER=$(kubectl get node --context kind-west -l node-role.kubernetes.io/control-plane -o json \
  | jq -r '.items[] | .status.addresses[] | select(.type=="InternalIP") | .address')

istioctl create-remote-secret \
  --context="kind-west" \
  --server ${WEST_SERVER} \
  --name=west | \
  kubectl apply -f - --context="kind-east"
