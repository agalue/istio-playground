#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

export CTX_CLUSTER1="kind-east"
export CTX_CLUSTER2="kind-west"

kubectl create namespace sample \
  --dry-run=client -o yaml | kubectl apply --context="${CTX_CLUSTER1}" -f -

kubectl create namespace sample \
  --dry-run=client -o yaml | kubectl apply --context="${CTX_CLUSTER2}" -f -

kubectl label --context="${CTX_CLUSTER1}" namespace sample \
  istio-injection=enabled --overwrite

kubectl label --context="${CTX_CLUSTER2}" namespace sample \
  istio-injection=enabled --overwrite

kubectl apply --context="${CTX_CLUSTER1}" \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml \
  -l service=helloworld -n sample

kubectl apply --context="${CTX_CLUSTER2}" \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml \
  -l service=helloworld -n sample

kubectl apply --context="${CTX_CLUSTER1}" \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml \
  -l version=v1 -n sample

kubectl apply --context="${CTX_CLUSTER2}" \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/helloworld/helloworld.yaml \
  -l version=v2 -n sample

kubectl apply --context="${CTX_CLUSTER1}" \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml -n sample

kubectl apply --context="${CTX_CLUSTER2}" \
  -f https://raw.githubusercontent.com/istio/istio/master/samples/sleep/sleep.yaml -n sample
