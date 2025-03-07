# Istio Playground

This is playground to have two [Kind](https://kind.sigs.k8s.io/) clusters backed by [Cilium](https://cilium.io/) as CNI (and allowing Load Balancer services to avoid MetalLB) connected with [Istio](https://istio.io/) using its [multi-cluster](https://istio.io/latest/docs/setup/install/multicluster/multi-primary/) capabilities. A flat network across the cluster is managed via Cilium [Cluster-Mesh](https://cilium.io/use-cases/cluster-mesh/).

# Requirements

* [Docker](http://docker.io/)
* [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/)
* [Helm](https://helm.sh/docs/intro/install/)
* [Step CLI](https://smallstep.com/docs/step-cli/installation/)
* [Istio CLI](https://istio.io/latest/docs/setup/install/istioctl/)
* [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
* [JQ](https://jqlang.github.io/jq/download/)

# Run

> This is a work in progress

The following deploys a traditional Istio with proxies (in other words, it assumes `ISTIO_PROFILE=default`):

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

If you want to use ambient mode, run the following *before* the above commands:
```bash
export ISTIO_PROFILE=ambient
```

# Verify

```bash
for ctx in "kind-east" "kind-west"; do
    echo "Context: $ctx"
    istioctl remote-clusters --context $ctx
done
```

You should see:
```
Context: kind-east
NAME     SECRET                                    STATUS     ISTIOD
east                                               synced     istiod-69c5b7b798-98gvc
west     istio-system/istio-remote-secret-west     synced     istiod-69c5b7b798-98gvc
Context: kind-west
NAME     SECRET                                    STATUS     ISTIOD
west                                               synced     istiod-79f47f9676-4h9v4
east     istio-system/istio-remote-secret-east     synced     istiod-79f47f9676-4h9v4
```

> *Warning*: As of version 1.25.0, the ambient mode doesn't officially support multi-cluster, so you won't see `synced`, but the solution works.

Based on [this](https://istio.io/latest/docs/setup/install/multicluster/verify/), the following deploy the testing workload:

```bash
./deploy-test.sh
```

After a few seconds, if you're using the traditional deployment via Istio-Proxy (Envoy), execute the following to see the endpoints:
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

If you're using Ambient mode, run the following instead:
```bash
❯ istioctl zc workload --workload-namespace sample
NAMESPACE POD NAME                       ADDRESS     NODE        WAYPOINT PROTOCOL
sample    helloworld-v1-5787f49bd8-d5slw 10.11.1.243 east-worker None     HBONE
sample    helloworld-v2-6746879bdd-nw8jn 10.12.1.154 west-worker None     HBONE
sample    sleep-868c754c4b-cmnsz         10.12.1.41  west-worker None     HBONE
sample    sleep-868c754c4b-jzzqz         10.11.1.181 east-worker None     HBONE
```

Note that we see endpoints from the worker nodes on different clusters. For more details:
```bash
❯ istioctl zc service --service-namespace=sample -o yaml
- endpoints:
    east//Pod/sample/helloworld-v1-5787f49bd8-d5slw:
      port:
        "5000": 5000
      service: ""
      workloadUid: east//Pod/sample/helloworld-v1-5787f49bd8-d5slw
    west//Pod/sample/helloworld-v2-6746879bdd-nw8jn:
      port:
        "5000": 5000
      service: ""
      workloadUid: west//Pod/sample/helloworld-v2-6746879bdd-nw8jn
  hostname: helloworld.sample.svc.cluster.local
  ipFamilies: IPv4
  name: helloworld
  namespace: sample
  ports:
    "5000": 5000
  vips:
  - /172.21.97.76
- endpoints:
    east//Pod/sample/sleep-868c754c4b-jzzqz:
      port:
        "80": 80
      service: ""
      workloadUid: east//Pod/sample/sleep-868c754c4b-jzzqz
    west//Pod/sample/sleep-868c754c4b-cmnsz:
      port:
        "80": 80
      service: ""
      workloadUid: west//Pod/sample/sleep-868c754c4b-cmnsz
  hostname: sleep.sample.svc.cluster.local
  ipFamilies: IPv4
  name: sleep
  namespace: sample
  ports:
    "80": 80
  vips:
  - /172.21.178.227
```

Note that the IP addresses are coming from both clusters.

To test connectivity, run the following multiple times:

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
