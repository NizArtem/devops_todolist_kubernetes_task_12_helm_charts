#!/bin/bash
kind create cluster --config cluster.yml

kubectl create ns mateapp
kubectl create ns todoapp
kubectl create ns mysql

helm upgrade --install todoapp . -n todoapp

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl taint nodes kind-worker app=mysql:NoSchedule --overwrite
kubectl taint nodes kind-worker2 app=mysql:NoSchedule --overwrite

helm dependency update .infrastructure/helm-chart/todoapp

helm upgrade --install todoapp .infrastructure/helm-chart/todoapp -n todoapp

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

kubectl get all,cm,secret,ing -A > "$PROJECT_ROOT/output.log"