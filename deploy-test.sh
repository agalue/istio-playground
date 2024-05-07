#!/bin/bash
#
# Source: https://istio.io/latest/docs/setup/install/multicluster/verify/

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

for cmd in "kubectl"; do
  type $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but it's not installed; aborting."; exit 1; }
done

for ctx in "kind-east" "kind-west"; do
  kubectl create namespace sample \
    --dry-run=client -o yaml | kubectl apply --context=$ctx -f -

  kubectl label --context=$ctx namespace sample \
    istio-injection=enabled --overwrite

  kubectl apply --context=$ctx \
    -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml \
    -l service=helloworld -n sample
done

kubectl apply --context=kind-east \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml \
  -l version=v1 -n sample

kubectl apply --context=kind-west \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml \
  -l version=v2 -n sample

for ctx in "kind-east" "kind-west"; do
  kubectl apply --context=$ctx \
    -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml -n sample
done
