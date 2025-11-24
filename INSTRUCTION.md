Validation Instructions

This document explains how to validate the required changes for the todoapp Helm chart (and its mysql subchart). Follow the steps below on your kind cluster or other Kubernetes cluster where you deployed the chart.

0. Preconditions

You have kubectl, helm and (optionally) kind installed and configured.

You ran the provided bootstrap.sh from the repository root (the script creates the todoapp namespace, installs ingress controller if needed, taints nodes, updates dependencies and installs the Helm release, and writes output.log).

If you didn't run bootstrap.sh, run it now:

chmod +x bootstrap.sh
./bootstrap.sh


bootstrap.sh should:

ensure namespace todoapp exists,

install ingress-nginx on kind (if required),

taint nodes labeled with app=mysql with app=mysql:NoSchedule (or apply taints as required),

helm dependency update .infrastructure/helm-chart/todoapp
helm upgrade --install todoapp .infrastructure/helm-chart/todoapp -n todoapp

and save kubectl get all,cm,secret,ing -A output to output.log.

1. Confirm the release is installed
helm list -n todoapp


Expected: a release named todoapp exists in namespace todoapp.

2. Inspect cluster resources (quick check)

Open output.log in the repository root:

cat output.log


This file was produced by kubectl get all,cm,secret,ing -A > output.log. Verify:

Pods, Deployments, StatefulSets, Services are present for both todoapp and mysql.

ConfigMaps and Secrets referenced by charts exist.

Ingress resources exist (if you configured ingress).

3. Check pods & workloads
kubectl get pods -n todoapp
kubectl get statefulset -n todoapp
kubectl describe statefulset <mysql-statefulset-name> -n todoapp


What to look for:

Pods are Running and READY.

MySQL StatefulSet has the expected number of replicas and ready replicas.

4. Verify image repository & tag are controlled by values.yaml

Render manifests and inspect container image:

helm template todoapp . -n todoapp > rendered.yaml
grep -n "image:" rendered.yaml


Expected: the image line comes from values, e.g.:

image: "mysql:8.0"   # or whatever values.yaml defines (repository:tag)


If you used a nested mysql.image in root values.yaml, check rendered.yaml for that value.

5. Verify PVC storage size comes from values.yaml

Check volumeClaimTemplates in StatefulSet (rendered or via kubectl):

kubectl get statefulset -n todoapp -o yaml | yq '.items[] | select(.metadata.name=="<mysql-statefulset-name>") | .spec.volumeClaimTemplates'
# or inspect rendered.yaml
grep -n "volumeClaimTemplates" -n rendered.yaml -A6


Expected: resources.requests.storage: <value from values.yaml> (e.g. 2Gi or the configured value).

6. Verify resource requests (and optional limits) come from values.yaml

Inspect container resources:

kubectl get pod -n todoapp -o yaml | yq '.items[][].spec.containers[] | {name: .name, resources: .resources}'
# or search rendered.yaml:
grep -n "resources:" -n rendered.yaml -A6


Expected: requests.cpu and requests.memory reflect values from values.yaml. If limits were added, they should reflect values.yaml too.

7. Verify Affinity and Tolerations are controlled from values.yaml
Check node/pod affinity (rendered or live)
# rendered.yaml
grep -n "affinity:" -n rendered.yaml -A12

# live check
kubectl get pod -n todoapp -o yaml | yq '.items[][].spec.affinity'


Expected: nodeAffinity and podAntiAffinity blocks use keys and values that match values.yaml entries (e.g. matchExpressions.key: app, values: ["mysql"], topologyKey etc).

Check tolerations on MySQL pods
kubectl describe pod <mysql-pod-name> -n todoapp | sed -n '/Tolerations:/,/Events:/p'


Expected: Pod has a toleration matching the node taint (for example, key=app, operator=Equal, value=mysql, effect=NoSchedule).

8. Verify node taints (the script should have tainted nodes labeled app=mysql)

List nodes with labels and taints:

kubectl get nodes --show-labels
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
# or
kubectl describe nodes | grep -A2 "Taints"


Also verify the taint was applied only to nodes that had app=mysql label if that was required:

kubectl get nodes -l app=mysql --show-labels
kubectl describe node <node-name-with-app-label>


Expected: nodes with label app=mysql have taint app=mysql:NoSchedule (or as configured).

9. Verify tolerations + scheduling behavior

If pods require the toleration to schedule on tainted nodes, confirm the MySQL pods are scheduled to those tainted nodes:

kubectl get pods -n todoapp -o wide


Check the NODE column; the MySQL pod(s) should be on nodes that have the taint (if intent was to place them there).

10. Verify Secrets mapping (range mapping)

Check that Secrets were created and that keys from values.yaml are present:

kubectl get secret mysql-secrets -n todoapp -o yaml


Inspect deployment/statefulset envs to confirm envs come from secret keys mapped via range:

grep -n "valueFrom:" rendered.yaml -A3
kubectl describe pod <pod-name> -n todoapp | sed -n '/Environment:/,/Mounts:/p'


Expected: each environment var references secretKeyRef: name: mysql-secrets key: <KEY> for all keys provided in values.yaml.

11. Verify RollingUpdate parameters are from values.yaml (if used in any Deployment)

If you have any Deployment with strategy RollingUpdate:

grep -n "rollingUpdate" -n rendered.yaml -A4


Expected: maxUnavailable and maxSurge match values set in values.yaml (not hard-coded numbers).

12. Linting & template checks (local)

Before installing/upgrading you can validate templates locally:

helm lint .
helm template todoapp . -n todoapp > rendered.yaml
# Inspect rendered.yaml for missing fields or invalid YAML


Common errors to watch for:

Arrays vs scalar substitution (use range for lists)

Missing quotes for strings that require them

values under matchExpressions must be a list of strings (use range to render)

13. Logs & troubleshooting

Check pod logs:

kubectl logs -n todoapp <pod-name> --follow


Describe problematic pod to see events:

kubectl describe pod -n todoapp <pod-name>


If Helm fails on install/upgrade, run:

helm install --dry-run --debug todoapp . -n todoapp


This shows exactly what Helm tried to render and apply.

14. Accessing the app (optional)

If todoapp exposes an HTTP service, port-forward:

kubectl port-forward svc/todoapp 8080:80 -n todoapp
# then open http://localhost:8080


If using Ingress with kind, ensure ingress-nginx is installed (bootstrap should install it), and access via host mapping or localhost depending on your setup.