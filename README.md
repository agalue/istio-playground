# Istio Playground

This is playground to have two [Kind](https://kind.sigs.k8s.io/) clusters backed by [Cilium](https://cilium.io/) as CNI (and allowing Load Balancer services to avoid MetalLB) connected with [Istio](https://istio.io/) using its [multi-cluster](https://istio.io/latest/docs/setup/install/multicluster/primary-remote_multi-network/) capabilities.

The environment assumes we're interconnecting two clusters from different networks using Istio. As everything is laid out to have different CIDR for Pods and Services, it could be possible to connect the clusters using Cilium ClusterMesh and then use the multi-cluster feature of Istio on a shared or single network. Still, that last use case is not covered here.

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

The following deploys a traditional Istio with proxies (in other words, it assumes `ISTIO_PROFILE=default`). 

However, if you want to use ambient mode, run the following *before* the above commands:
```bash
export ISTIO_PROFILE=ambient
export CILIUM_ENABLED=false
```

> DNS doesn't work well when having Cilium and Istio in Ambient mode. Disabling Cilium uses default Kind CNI and MetalLB for LoadBalancers.

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

Based on [this](https://istio.io/latest/docs/setup/install/multicluster/verify/), the following deploy the testing workload:

```bash
./deploy-test.sh
```

For the proxy-based solution, execute the following after a few seconds:
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
10.11.1.248:5000                                        HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
192.168.228.242:15443                                   HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
Context: kind-west
10.21.1.3:5000                                          HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
192.168.228.250:15443                                   HEALTHY     OK                outbound|5000||helloworld.sample.svc.cluster.local
```

The IP addresses that start with `192.168.228.` are the public IP of the LB from the sibling cluster:

```bash
for ctx in "kind-east" "kind-west"; do
    echo "Context: $ctx"
    kubectl --context $ctx get svc -n istio-system istio-eastwestgateway
done
```

The above produces:

```bash
Context: kind-east
NAME                    TYPE           CLUSTER-IP    EXTERNAL-IP       PORT(S)                                                           AGE
istio-eastwestgateway   LoadBalancer   10.12.7.171   192.168.228.250   15021:31815/TCP,15443:30465/TCP,15012:32123/TCP,15017:30309/TCP   4m21s
Context: kind-west
NAME                    TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)                                                           AGE
istio-eastwestgateway   LoadBalancer   10.22.249.140   192.168.228.242   15021:30742/TCP,15443:31607/TCP,15012:32301/TCP,15017:31203/TCP   2m59s
```

If you're using Ambient mode, run the following instead:
```bash
❯ istioctl zc workload --workload-namespace sample
NAMESPACE POD NAME                                                                                                               ADDRESS     NODE        WAYPOINT PROTOCOL
sample    east/SplitHorizonWorkload/istio-system/istio-eastwestgateway/192.168.97.248/sample/helloworld.sample.svc.cluster.local                         None     HBONE
sample    helloworld-v2-6746879bdd-jmwtw                                                                                         10.12.1.173 west-worker None     HBONE
sample    sleep-868c754c4b-22w5t                                                                                                 10.12.1.249 west-worker None     HBONE
```

For more details:
```bash
❯ istioctl zc service --service-namespace=sample -o yaml
- endpoints:
    east/SplitHorizonWorkload/istio-system/istio-eastwestgateway/192.168.97.248/sample/helloworld.sample.svc.cluster.local:
      port:
        "5000": 5000
      service: ""
      workloadUid: east/SplitHorizonWorkload/istio-system/istio-eastwestgateway/192.168.97.248/sample/helloworld.sample.svc.cluster.local
    west//Pod/sample/helloworld-v2-6746879bdd-jmwtw:
      port:
        "5000": 5000
      service: ""
      workloadUid: west//Pod/sample/helloworld-v2-6746879bdd-jmwtw
  hostname: helloworld.sample.svc.cluster.local
  ipFamilies: IPv4
  name: helloworld
  namespace: sample
  ports:
    "5000": 5000
  subjectAltNames:
  - spiffe://cluster.local/ns/sample/sa/default
  vips:
  - east/172.21.230.204
  - west/172.22.46.175
- endpoints:
    west//Pod/sample/sleep-868c754c4b-22w5t:
      port:
        "80": 80
      service: ""
      workloadUid: west//Pod/sample/sleep-868c754c4b-22w5t
  hostname: sleep.sample.svc.cluster.local
  ipFamilies: IPv4
  name: sleep
  namespace: sample
  ports:
    "80": 80
  vips:
  - west/172.22.159.217
```

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
