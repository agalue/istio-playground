# Istio Multi-Cluster Playground

A comprehensive hands-on environment for exploring Istio's multi-cluster capabilities across different data plane modes. This playground demonstrates how to establish secure service mesh connectivity between Kubernetes clusters using both traditional sidecar proxies and the innovative ambient mesh architecture.

## 🎯 What You'll Learn

- **Multi-cluster mesh architecture** using Istio's primary-remote topology across different networks
- **Ambient mesh mode** - Istio's sidecar-free data plane option (stable since 1.27.0)
- **Traditional proxy-based mesh** - The proven sidecar approach
- **Cross-cluster service discovery** and load balancing
- **Certificate management** for secure inter-cluster communication
- **CNI integration** with Cilium for enhanced networking capabilities

## 🏗️ Architecture Overview

This playground creates two Kind clusters (`east` and `west`) connected via Istio multi-cluster:

```
┌─────────────────┐    ┌─────────────────┐
│   East Cluster  │◄──►│   West Cluster  │
│   (Primary)     │    │   (Primary)     │
│                 │    │                 │
│ Pod CIDR:       │    │ Pod CIDR:       │
│ 10.11.0.0/16    │    │ 10.21.0.0/16    │
│                 │    │                 │
│ Service CIDR:   │    │ Service CIDR:   │
│ 172.21.0.0/16   │    │ 172.22.0.0/16   │
└─────────────────┘    └─────────────────┘
```

**Key Features:**
- **Separate networks**: Each cluster operates in its own network with distinct CIDRs
- **Dual CNI support**: Cilium (default) or Kind's default CNI with MetalLB
- **Flexible deployment**: Choose between ambient or traditional sidecar modes
- **Automated setup**: Scripts handle the complex multi-cluster configuration

> **Note**: While these clusters could theoretically be connected using Cilium ClusterMesh for a single-network setup, this playground focuses specifically on the multi-network scenario, which is more common in production environments.

# Requirements

Ensure you have the following tools installed before proceeding:

| Tool | Purpose | Installation Guide |
|------|---------|-------------------|
| [Docker](http://docker.io/) | Container runtime for Kind clusters | [Install Docker](https://docs.docker.com/get-docker/) |
| [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) | Kubernetes in Docker - creates local clusters | [Install Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| [Kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes command-line tool | [Install kubectl](https://kubernetes.io/docs/tasks/tools/) |
| [Helm](https://helm.sh/docs/intro/install/) | Package manager for Kubernetes | [Install Helm](https://helm.sh/docs/intro/install/) |
| [Step CLI](https://smallstep.com/docs/step-cli/installation/) | Certificate authority and crypto toolkit | [Install Step CLI](https://smallstep.com/docs/step-cli/installation/) |
| [Istio CLI](https://istio.io/latest/docs/setup/install/istioctl/) | Istio service mesh management | [Install istioctl](https://istio.io/latest/docs/setup/install/istioctl/) |
| [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/) | Cilium CNI management (optional) | [Install Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/) |
| [JQ](https://jqlang.github.io/jq/download/) | JSON processor for script automation | [Install jq](https://jqlang.github.io/jq/download/) |

## 🚀 Quick Start

### Configuration Options

Before deploying, choose your preferred setup:

#### **Data Plane Mode Selection**
```bash
# For traditional sidecar proxy mode (default)
export ISTIO_PROFILE=default

# For ambient mesh mode (sidecar-free)
export ISTIO_PROFILE=ambient
```

> **💡 Tip**: Ambient mode offers simplified operations and reduced resource overhead by eliminating sidecars, while traditional mode provides battle-tested stability and extensive feature support.

#### **CNI Configuration**
```bash
# Use Cilium CNI (recommended - includes LoadBalancer support)
export CILIUM_ENABLED=true  # default

# Use Kind's default CNI with MetalLB
export CILIUM_ENABLED=false
```

### Deployment Steps

Execute these scripts in sequence to build your multi-cluster environment:

```bash
# 1. Generate root and intermediate certificates for secure inter-cluster communication
./deploy-certs.sh

# 2. Deploy the East cluster (primary)
./deploy-east.sh

# 3. Deploy the West cluster (primary) 
./deploy-west.sh

# 4. Establish cross-cluster connectivity
./deploy-secrets.sh
```

**What each script does:**
- `deploy-certs.sh`: Creates a PKI hierarchy with root CA and intermediate certificates for each cluster
- `deploy-east.sh`/`deploy-west.sh`: Provisions Kind clusters with Istio, configures networking, and sets up east-west gateways
- `deploy-secrets.sh`: Exchanges cluster secrets to enable cross-cluster service discovery

# 🔍 Verification & Testing

## Cluster Connectivity Verification

First, verify that both clusters can see each other:

```bash
for ctx in "kind-east" "kind-west"; do
    echo "=== Context: $ctx ==="
    istioctl remote-clusters --context $ctx
    echo
done
```

**Expected output:**
```
=== Context: kind-east ===
NAME     SECRET                                    STATUS     ISTIOD
east                                               synced     istiod-69c5b7b798-98gvc
west     istio-system/istio-remote-secret-west     synced     istiod-69c5b7b798-98gvc

=== Context: kind-west ===
NAME     SECRET                                    STATUS     ISTIOD
west                                               synced     istiod-79f47f9676-4h9v4
east     istio-system/istio-remote-secret-east     synced     istiod-79f47f9676-4h9v4
```

✅ **Success indicators:**
- Both clusters show "synced" status
- Each cluster recognizes itself and its remote peer
- Istiod instances are healthy in both clusters

## Deploy Test Workloads

Deploy the sample applications to test cross-cluster communication:

```bash
./deploy-test.sh
```

This script deploys:
- `helloworld-v1` service in the East cluster  
- `helloworld-v2` service in the West cluster
- `sleep` pods in both clusters for testing connectivity

## Testing by Data Plane Mode

### Traditional Proxy-Based Mode

For sidecar proxy deployments, verify endpoint discovery:

```bash
for ctx in "kind-east" "kind-west"; do
    echo "=== Proxy endpoints in $ctx ==="
    pod_name=$(kubectl --context $ctx get pod -n sample -l app=sleep -o jsonpath='{.items[0].metadata.name}')
    istioctl --context $ctx proxy-config endpoint $pod_name.sample | grep helloworld
    echo
done
```

**Expected output:**
```
=== Proxy endpoints in kind-east ===
10.11.1.248:5000                     HEALTHY     OK    outbound|5000||helloworld.sample.svc.cluster.local
192.168.228.242:15443                HEALTHY     OK    outbound|5000||helloworld.sample.svc.cluster.local

=== Proxy endpoints in kind-west ===
10.21.1.3:5000                       HEALTHY     OK    outbound|5000||helloworld.sample.svc.cluster.local  
192.168.228.250:15443                HEALTHY     OK    outbound|5000||helloworld.sample.svc.cluster.local
```

**Understanding the endpoints:**
- `10.x.x.x:5000` - Local pod IP in the same cluster
- `192.168.228.x:15443` - Remote cluster's east-west gateway IP (cross-cluster traffic)

### Cross-Cluster Gateway Verification

Check the east-west gateway services that enable cross-cluster communication:

```bash
for ctx in "kind-east" "kind-west"; do
    echo "=== East-West Gateway in $ctx ==="
    kubectl --context $ctx get svc -n istio-system istio-eastwestgateway
    echo
done
```
**Expected output:**
```
=== East-West Gateway in kind-east ===
NAME                    TYPE           CLUSTER-IP    EXTERNAL-IP       PORT(S)
istio-eastwestgateway   LoadBalancer   10.12.7.171   192.168.228.250   15021:31815/TCP,15443:30465/TCP,15012:32123/TCP,15017:30309/TCP

=== East-West Gateway in kind-west ===
NAME                    TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)
istio-eastwestgateway   LoadBalancer   10.22.249.140   192.168.228.242   15021:30742/TCP,15443:31607/TCP,15012:32301/TCP,15017:31203/TCP
```

### Ambient Mode Verification

For ambient mesh deployments, use the zero-config commands to inspect workload and service discovery:

#### Workload Discovery
```bash
istioctl ztunnel-config workload --workload-namespace sample
```

**Expected output:**
```
NAMESPACE POD NAME                                                                    ADDRESS     NODE        WAYPOINT PROTOCOL
sample    east/SplitHorizonWorkload/istio-system/istio-eastwestgateway/192.168.97.248 -           -           None     HBONE
sample    helloworld-v2-6746879bdd-g4n4z                                             10.12.1.240 west-worker None     HBONE  
sample    sleep-868c754c4b-pqjc2                                                     10.12.1.202 west-worker None     HBONE
```

#### Service Configuration
```bash
istioctl ztunnel-config service --service-namespace=sample -o yaml
```

**Key points about ambient mode:**
- **No sidecars**: Workloads run without proxy containers
- **HBONE protocol**: HTTP/2-based overlay network for secure communication
- **Ztunnel**: Node-level proxy handles L4 processing
- **Split horizon**: Remote endpoints appear as gateway workloads

## End-to-End Connectivity Testing

Test actual service-to-service communication across clusters:

### From East Cluster
```bash
kubectl exec --context="kind-east" -n sample -c sleep \
    "$(kubectl get pod --context="kind-east" -n sample -l app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

### From West Cluster  
```bash
kubectl exec --context="kind-west" -n sample -c sleep \
    "$(kubectl get pod --context="kind-west" -n sample -l app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

### Expected Behavior

Run either command multiple times and observe load balancing between clusters:

```bash
Hello version: v1, instance: helloworld-v1-7459d7b54b-mbjjc  # East cluster
Hello version: v2, instance: helloworld-v2-654d97458-fm9m2  # West cluster  
Hello version: v1, instance: helloworld-v1-7459d7b54b-mbjjc  # East cluster
Hello version: v2, instance: helloworld-v2-654d97458-fm9m2  # West cluster
```

✅ **Success criteria:**
- Responses alternate between v1 (East) and v2 (West)
- No connection failures or timeouts
- Consistent response times indicating healthy cross-cluster routing

## 🔧 Troubleshooting

### Common Issues and Solutions

#### **Clusters not discovering each other**
```bash
# Check if remote secrets exist
kubectl --context kind-east get secrets -n istio-system | grep remote
kubectl --context kind-west get secrets -n istio-system | grep remote

# Verify secret contents
kubectl --context kind-east get secret istio-remote-secret-west -n istio-system -o yaml
```

#### **East-west gateway not getting external IP**
```bash
# For Cilium deployments
kubectl --context kind-east get svc -n istio-system istio-eastwestgateway
cilium status --context kind-east

# For MetalLB deployments  
kubectl --context kind-east get configmap -n metallb-system config -o yaml
```

#### **Ambient mode workloads not communicating**
```bash
# Check ztunnel daemonset
kubectl --context kind-east get ds -n istio-system ztunnel
kubectl --context kind-east logs -n istio-system -l app=ztunnel

# Verify CNI installation
kubectl --context kind-east get ds -n istio-system istio-cni-node
```

#### **Certificate issues**
```bash
# Verify root certificates match
kubectl --context kind-east get configmap istio-ca-root-cert -n istio-system -o jsonpath='{.data.root-cert\.pem}' | head -1
kubectl --context kind-west get configmap istio-ca-root-cert -n istio-system -o jsonpath='{.data.root-cert\.pem}' | head -1
```

### Debug Commands

```bash
# Analyze proxy configuration (traditional mode)
istioctl --context kind-east proxy-status
istioctl --context kind-west proxy-status

# Check ambient mode configuration
istioctl --context kind-east ztunnel-config all
istioctl --context kind-west ztunnel-config all
```

## 🧹 Cleanup

Remove all resources when you're done experimenting:

```bash
# Delete Kind clusters
kind delete cluster --name east
kind delete cluster --name west

# Clean up certificates
rm -rf certs/

# Reset environment variables (optional)
unset ISTIO_PROFILE CILIUM_ENABLED
```

## 📚 Learning Resources

### Key Concepts Explored

- **[Istio Multi-cluster](https://istio.io/latest/docs/setup/install/multicluster/)**: Production patterns for service mesh across clusters
- **[Ambient Mesh](https://istio.io/latest/docs/ambient/)**: Sidecar-free service mesh architecture  
- **[Primary-Remote Multi-network](https://istio.io/latest/docs/setup/install/multicluster/primary-remote_multi-network/)**: The specific topology used in this playground
- **[Cilium CNI](https://cilium.io/)**: eBPF-based networking and security
- **[Cross-cluster Service Discovery](https://istio.io/latest/docs/ops/deployment/deployment-models/#cross-cluster-service-discovery)**: How services find each other across clusters

### Next Steps

1. **Explore Traffic Management**: Implement traffic splitting, fault injection, and circuit breaking across clusters
2. **Security Policies**: Set up authorization policies and security rules for cross-cluster communication  
3. **Observability**: Add monitoring, tracing, and logging to understand cross-cluster behavior
4. **Production Patterns**: Adapt this setup for cloud environments with real clusters

### Recommended Reading

- [Istio Deployment Models](https://istio.io/latest/docs/ops/deployment/deployment-models/)
- [Ambient Mesh Architecture](https://istio.io/latest/docs/ambient/architecture/)  
- [Multi-cluster Best Practices](https://istio.io/latest/docs/ops/best-practices/multicluster/)
- [Cilium Multi-cluster](https://docs.cilium.io/en/stable/network/clustermesh/)

---

**Happy meshing!** 🕸️ If you encounter issues or have suggestions, please open an issue in this repository.
