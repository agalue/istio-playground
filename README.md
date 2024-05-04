# Istio Playground

This is playground to have two clusters connected with Istio.

# Run

> This is a work in progress

```bash
./deploy-certs.sh
./deploy-east.sh
./deploy-west.sh
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

Based on [this](https://istio.io/latest/docs/setup/install/multicluster/verify/):

```bash
export CTX_CLUSTER1="kind-east"
export CTX_CLUSTER2="kind-west"

./deploy-test.sh
```

After a few seconds:
```bash
for ctx in "${CTX_CLUSTER1}" "${CTX_CLUSTER2}"; do
    echo "Context: $ctx"
    pod_name=$(kubectl --context $ctx get pod -n sample -l app=sleep -o jsonpath='{.items[0].metadata.name}')
    istioctl --context $ctx proxy-config endpoint $pod_name.sample | grep helloworld
done
```

Then,
```bash
kubectl exec --context="${CTX_CLUSTER1}" -n sample -c sleep \
    "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

Or,
```bash
kubectl exec --context="${CTX_CLUSTER2}" -n sample -c sleep \
    "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

You should see alternate output from the services on each cluster.

