#!/bin/bash

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

CONTEXT=${CONTEXT-east} # Unique on each cluster
SUBNET=${SUBNET-248} # Last octet from the /29 CIDR subnet to use for LoadBalancer IPs
WORKERS=${WORKERS-1}
CLUSTER_ID=${CLUSTER_ID-1} # Unique on each cluster
POD_CIDR=${POD_CIDR-10.11.0.0/16} # Pod subnet for the cluster (when using Cilium, it must be under 10.0.0.0/8 for ipv4NativeRoutingCIDR)
SVC_CIDR=${SVC_CIDR-172.21.0.0/16} # Must differ from Kind's Docker Network

echo "Deploying Kubernetes"
. deploy-kind.sh
