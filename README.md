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

https://istio.io/latest/docs/setup/install/multicluster/verify/

```bash
export CTX_CLUSTER1="kind-east"
export CTX_CLUSTER2="kind-west"

./deploy-test.sh
```

Then,

```bash
kubectl exec --context="${CTX_CLUSTER1}" -n sample -c sleep \
    "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

And

```bash
kubectl exec --context="${CTX_CLUSTER2}" -n sample -c sleep \
    "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -sS helloworld.sample:5000/hello
```

Additionally,

```bash
for ctx in "${CTX_CLUSTER1}" "${CTX_CLUSTER2}"; do
    echo "Context: $ctx"
    pod_name=$(kubectl --context $ctx get pod -n sample -l app=sleep -o jsonpath='{.items[0].metadata.name}')
    istioctl --context $ctx proxy-config endpoint $pod_name.sample | grep helloworld
done
```