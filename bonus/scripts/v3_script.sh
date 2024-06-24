#!/bin/bash

# Configuration
cluster_name="gitlab"
app_repo="git@gitlab-gitlab-shell.gitlab.svc.cluster.local:root/test.git"
app_path="app/"
app_name="iot-p3-app"
app_namespace="dev"

# Colors
GREEN="\e[32m"
ENDCOLOR="\e[0m"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Install Argo CD
echo -e "${GREEN}Installing Argo CD${ENDCOLOR}"
kubectl create namespace argocd
helm repo add argocd https://argoproj.github.io/argo-helm
helm install argocd argocd/argo-cd \
    --namespace argocd \
    --set configs.cm."timeout\.reconciliation"=20s
# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Argo CD CLI
if ! command -v argocd &> /dev/null
then
    echo -e "${GREEN}Installing Argo CD CLI${ENDCOLOR}"
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi

# Waiting for argocd to be ready
kubectl rollout status deployment argocd-server -n argocd
kubectl rollout status deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-dex-server -n argocd
kubectl rollout status deployment argocd-applicationset-controller -n argocd

# Deploy app from remote repo
echo -e "${GREEN}Deploying app $app_name from $app_repo${ENDCOLOR}"
kubectl port-forward svc/argocd-server -n argocd 7845:443 &
PORT_PID=$!
echo -e "${GREEN}Port forward pid: $PORT_PID${ENDCOLOR}"
sleep 3
argocd login localhost:7845 --insecure \
    --username admin \
    --password $(kubectl get secret argocd-initial-admin-secret --namespace=argocd --template={{.data.password}} | base64 -d)
kubectl create namespace $app_namespace
argocd repo add $app_repo --insecure-skip-server-verification --ssh-private-key-path ~/.ssh/id_rsa
argocd app create $app_name \
    --repo $app_repo \
    --path $app_path \
    --dest-namespace $app_namespace \
    --dest-server https://kubernetes.default.svc \
    --directory-recurse \
    --sync-policy automated
kill $PORT_PID
sleep 3

# Waiting for iot-app to be ready
kubectl rollout status deployment iot-app-deployment -n $app_namespace
# Forwarding ports for app and argocd-server
${SCRIPT_DIR}/../../p3/scripts/forward_ports.sh
echo -e "${GREEN}DONE!${ENDCOLOR}"
