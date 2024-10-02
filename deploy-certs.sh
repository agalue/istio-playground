#!/bin/bash
#
# Source: https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

for cmd in "step"; do
  type $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but it's not installed; aborting."; exit 1; }
done

mkdir -p certs
pushd certs

step certificate create \
  "Root CA" \
  root-cert.pem root-key.pem \
  --profile root-ca \
  --no-password --insecure \
  --force

for cluster in "East" "West"; do
  ctx=$(echo ${cluster} | tr '[:upper:]' '[:lower:]')
  mkdir -p ${ctx}
  step certificate create \
    "${cluster} Istio" \
    ${ctx}/ca-cert.pem ${ctx}/ca-key.pem \
    --profile intermediate-ca \
    --no-password --insecure \
    --ca root-cert.pem --ca-key root-key.pem \
    --force
  cat ${ctx}/ca-cert.pem root-cert.pem > ${ctx}/cert-chain.pem
  cp -f root-cert.pem ${ctx}/
done

popd