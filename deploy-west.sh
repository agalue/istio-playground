#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONTEXT=${CONTEXT-west}
DOMAIN=${DOMAIN-${CONTEXT}.cluster.local}
SUBNET=${SUBNET-240} # For Cilium L2/LB (must be unique across all clusters)
WORKERS=${WORKERS-1}
CLUSTER_ID=${CLUSTER_ID-2} # Unique on each cluster
POD_CIDR=${POD_CIDR-10.21.0.0/16} # Unique on each cluster
SVC_CIDR=${SVC_CIDR-10.22.0.0/16} # Unique on each cluster

echo "Deploying Kubernetes"
. deploy-kind.sh
