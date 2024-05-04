#!/bin/bash
#
# Source: https://github.com/agalue/LGTM-PoC/blob/main/deploy-kind.sh

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

for cmd in "docker" "kind" "cilium" "kubectl" "jq" "helm" "istioctl"; do
  type $cmd >/dev/null 2>&1 || { echo >&2 "$cmd required but it's not installed; aborting."; exit 1; }
done

CONTEXT=${CONTEXT-test} # Kubernetes Context Name (in Kind, it would be `kind-${CONTEXT}`)
WORKERS=${WORKERS-2} # Number of worker nodes in the clusters
SUBNET=${SUBNET-248} # Last octet from the /29 CIDR subnet to use for Cilium L2/LB
CLUSTER_ID=${CLUSTER_ID-1}
POD_CIDR=${POD_CIDR-10.244.0.0/16}
SVC_CIDR=${SVC_CIDR-10.96.0.0/12}
CILIUM_VERSION=${CILIUM_VERSION-1.15.4}

# Abort if the cluster exists; if so, ensure the kubeconfig is exported
CLUSTERS=($(kind get clusters | tr '\n' ' '))
if [[ ${#CLUSTERS[@]} > 0 ]] && [[ " ${CLUSTERS[@]} " =~ " ${CONTEXT} " ]]; then
  echo "Cluster ${CONTEXT} already started"
  kubectl config use-context kind-${CONTEXT}
  return
fi

WORKER_YAML=""
for ((i = 1; i <= WORKERS; i++)); do
  WORKER_YAML+=$(cat <<EOF
- role: worker
  labels:
    topology.kubernetes.io/region: ${CONTEXT}
    topology.kubernetes.io/zone: zone${i}
EOF
)$'\n'
done

# Deploy Kind Cluster
cat <<EOF | kind create cluster --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CONTEXT}
nodes:
- role: control-plane
${WORKER_YAML}
networking:
  ipFamily: ipv4
  disableDefaultCNI: true
  kubeProxyMode: none
  podSubnet: ${POD_CIDR}
  serviceSubnet: ${SVC_CIDR}
EOF

# https://docs.cilium.io/en/latest/network/servicemesh/istio/
cilium install --version ${CILIUM_VERSION} --wait \
  --set ipv4NativeRoutingCIDR=10.0.0.0/8 \
  --set cluster.id=${CLUSTER_ID} \
  --set cluster.name=${CONTEXT} \
  --set ipam.mode=kubernetes \
  --set devices=eth+ \
  --set l2announcements.enabled=true \
  --set externalIPs.enabled=true \
  --set socketLB.enabled=true \
  --set socketLB.hostNamespaceOnly=true \
  --set cni.exclusive=true \
  --set k8sClientRateLimit.qps=50 \
  --set k8sClientRateLimit.burst=100

cilium status --wait --ignore-warnings

NETWORK=$(docker network inspect kind \
  | jq -r '.[0].IPAM.Config[] | select(.Gateway != null) | .Subnet' | grep -v ':')
CIDR=""
if [[ "$NETWORK" == *"/16" ]]; then
  CIDR="${NETWORK%.*.*}.255.${SUBNET}/29"
fi
if [[ "$NETWORK" == *"/24" ]]; then
  CIDR="${NETWORK%.*}.${SUBNET}/29"
fi
if [[ "$CIDR" == "" ]]; then
  echo "cannot extract LB CIDR from network $NETWORK"
  exit 1
fi

cat <<EOF | kubectl apply -f -
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: ${CONTEXT}-pool
spec:
  cidrs:
  - cidr: "${CIDR}"
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: ${CONTEXT}-policy
spec:
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: DoesNotExist
  interfaces:
  - ^eth[0-9].*
  externalIPs: true
  loadBalancerIPs: true
EOF

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server \
 -n kube-system --set args={--kubelet-insecure-tls}

kubectl create namespace istio-system
kubectl label namespace istio-system topology.istio.io/network=${CONTEXT}
kubectl create secret generic cacerts -n istio-system \
  --from-file=certs/${CONTEXT}/ca-cert.pem \
  --from-file=certs/${CONTEXT}/ca-key.pem \
  --from-file=certs/${CONTEXT}/root-cert.pem \
  --from-file=certs/${CONTEXT}/cert-chain.pem

# https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/
# https://istio.io/latest/docs/reference/config/istio.operator.v1alpha1/
# https://istio.io/v1.5/docs/reference/config/installation-options/
cat <<EOF | istioctl install -y -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        enabled: true
        clusterName: ${CONTEXT}
      network: ${CONTEXT}
EOF

cat <<EOF | istioctl install -y -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: eastwest
spec:
  profile: empty
  components:
    ingressGateways:
    - name: istio-eastwestgateway
      label:
        istio: eastwestgateway
        app: istio-eastwestgateway
        topology.istio.io/network: ${CONTEXT}
      enabled: true
      k8s:
        env:
        # traffic through this gateway should be routed inside the network
        - name: ISTIO_META_REQUESTED_NETWORK_VIEW
          value: ${CONTEXT}
        service:
          ports:
          - name: status-port
            port: 15021
            targetPort: 15021
          - name: tls
            port: 15443
            targetPort: 15443
          - name: tls-istiod
            port: 15012
            targetPort: 15012
          - name: tls-webhook
            port: 15017
            targetPort: 15017
  values:
    gateways:
      istio-ingressgateway:
        injectionTemplate: gateway
    global:
      network: ${CONTEXT}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: cross-network-gateway
spec:
  selector:
    istio: eastwestgateway
  servers:
  - port:
      number: 15443
      name: tls
      protocol: TLS
    tls:
      mode: AUTO_PASSTHROUGH
    hosts:
    - "*.local"
EOF
