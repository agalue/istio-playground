#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONTEXT=${CONTEXT-east} # Unique on each cluster
SUBNET=${SUBNET-248} # For Cilium L2/LB (must be unique across all clusters)
WORKERS=${WORKERS-1}
CLUSTER_ID=${CLUSTER_ID-1} # Unique on each cluster
POD_CIDR=${POD_CIDR-10.11.0.0/16} # Must be under 10.0.0.0/8 for Cilium ipv4NativeRoutingCIDR
SVC_CIDR=${SVC_CIDR-172.21.0.0/16} # Node that Kind Docker Network is 172.18.0.0/16 by default (worker nodes)

echo "Deploying Kubernetes"
. deploy-kind.sh
