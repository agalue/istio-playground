#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

type make >/dev/null 2>&1 || { echo >&2 "make required but it's not installed; aborting."; exit 1; }

pushd certs

rm -rf root-* east west
make -f Makefile.selfsigned.mk root-ca
make -f Makefile.selfsigned.mk east-cacerts
make -f Makefile.selfsigned.mk west-cacerts

popd
