#!/bin/bash
kind create cluster --config cluster.yml

kubectl create ns mateapp
kubectl create ns todoapp
kubectl create ns mysql

helm upgrade --install todoapp . -n todoapp

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
