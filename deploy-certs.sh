#!/bin/bash
#
# Source: https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

for cmd in "make" "openssl"; do
  type $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but it's not installed; aborting."; exit 1; }
done

pushd certs

rm -rf root-* east west
make -f Makefile.selfsigned.mk root-ca
make -f Makefile.selfsigned.mk east-cacerts
make -f Makefile.selfsigned.mk west-cacerts

popd
