# Istio Playground

This is playground to have two [Kind](https://kind.sigs.k8s.io/) clusters backed by [Cilium](https://cilium.io/) as CNI (and allowing Load Balancer services to avoid MetalLB) connected with [Istio](https://istio.io/) using its [multi-cluster](https://istio.io/latest/docs/setup/install/multicluster/multi-primary/) capabilities. A flat network across the cluster is managed via Cilium [Cluster-Mesh](https://cilium.io/use-cases/cluster-mesh/).

# Run

> This is a work in progress

```bash
# Create the root and intermediate CAs for the backplane
./deploy-certs.sh
# Start the East cluster
./deploy-east.sh
# Start the West cluster
./deploy-west.sh
# Update the remote secrets to interconnect the clusters
./deploy-secrets.sh
```

# Verify

```bash
❯ istioctl remote-clusters --context kind-east
NAME     SECRET                                    STATUS     ISTIOD
west     istio-system/istio-remote-secret-west     synced     istiod-59844d9b-gdxcm

❯ istioctl remote-clusters --context kind-west
NAME     SECRET                                    STATUS     ISTIOD
east     istio-system/istio-remote-secret-east     synced     istiod-7cc75fd4c8-zw6q4
```

Based on [this](https://istio.io/latest/docs/setup/install/multicluster/verify/), the following deploy the testing workload:

```bash
./deploy-test.sh
```

After a few seconds:
```bash
for ctx in "kind-east" "kind-west"; do
    echo "Context: $ctx"
    pod_name=$(kubectl --context $ctx get pod -n sample -l app=sleep -o jsonpath='{.items[0].metadata.name}')
    istioctl --context $ctx proxy-config endpoint $pod_name.sample | grep helloworld
done
```

You should see:

```bash
Context: kind-east
10.11.1.206:5000                                        HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
10.21.1.185:5000                                        HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
Context: kind-west
10.11.1.206:5000                                        HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
10.21.1.185:5000                                        HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
```

Note that the IP addresses are coming from both clusters.

To test connectivity, run the following:

```bash
kubectl exec --context="kind-east" -n sample -c sleep \
    "$(kubectl get pod --context="kind-east" -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

Or,

```bash
kubectl exec --context="kind-west" -n sample -c sleep \
    "$(kubectl get pod --context="kind-west" -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

From any of the last two commands, you should see in the output an alternate response from the service on each cluster, for instance:

```bash
Hello version: v1, instance: helloworld-v1-7459d7b54b-mbjjc
Hello version: v2, instance: helloworld-v2-654d97458-fm9m2
Hello version: v1, instance: helloworld-v1-7459d7b54b-mbjjc
Hello version: v2, instance: helloworld-v2-654d97458-fm9m2
```
