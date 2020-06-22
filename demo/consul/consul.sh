#!/bin/bash
set -v

echo "Installing Consul from Helm chart repo..."
rm -rf ./consul-helm
git clone https://github.com/hashicorp/consul-helm.git
cd consul-helm; git checkout master ; cd ..
helm install consul -f ./values.yaml ./consul-helm

sleep 10s

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"consul": ["$(kubectl get svc consul-consul-dns -o jsonpath='{.spec.clusterIP}')"]}
EOF

sleep 10s

nohup kubectl port-forward service/consul-consul-ui 8500:80 --pod-running-timeout=10m &

kubectl wait --timeout=180s --for=condition=Ready $(kubectl get pod --selector=app=consul -o name)

sleep 10s

#Configure ingress gateway to transit/transform app
consul config write k8s-transit-app.hcl

echo ""
echo -n "Your Consul UI is at: http://localhost:8500"

open http://localhost:8500
