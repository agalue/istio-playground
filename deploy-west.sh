#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONTEXT=${CONTEXT-west} # Unique on each cluster
SUBNET=${SUBNET-240} # For Cilium L2/LB (must be unique across all clusters)
WORKERS=${WORKERS-1}
CLUSTER_ID=${CLUSTER_ID-2} # Unique on each cluster
POD_CIDR=${POD_CIDR-10.12.0.0/16} # Must be under 10.0.0.0/8 for Cilium ipv4NativeRoutingCIDR
SVC_CIDR=${SVC_CIDR-172.22.0.0/16} # Must differ from Kind's Docker Network

echo "Deploying Kubernetes"
. deploy-kind.sh
