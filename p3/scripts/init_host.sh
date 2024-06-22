#!/bin/bash

# Configuration
cluster_name="test"
app_repo="https://github.com/rabarbra/iot-p3-psimonen-valmpani.git"
app_path="app/"
app_name="iot-p3-app"
app_namespace="dev"

# Colors
GREEN="\e[32m"
ENDCOLOR="\e[0m"

# Install Docker
if ! command -v docker &> /dev/null
then
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Install kubectl
if ! command -v kubectl &> /dev/null
then
    echo -e "${GREEN}Installing kubectl${ENDCOLOR}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Install k3d
if ! command -v k3d &> /dev/null
then
    echo -e "${GREEN}Installing k3d${ENDCOLOR}"
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# Create cluster
if ! k3d cluster list $cluster_name &> /dev/null
then
    echo -e "${GREEN}Creating cluster${ENDCOLOR}"
    k3d cluster create $cluster_name
fi
echo -e "${GREEN}Cluster nodes:${ENDCOLOR}"
kubectl get nodes

# Install Argo CD
echo -e "${GREEN}Installing Argo CD${ENDCOLOR}"
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Argo CD CLI
if ! command -v argocd &> /dev/null
then
    echo -e "${GREEN}Installing Argo CD CLI${ENDCOLOR}"
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi

# Deploy app from remote repo
echo -e "${GREEN}Deploying app $app_name from $app_repo${ENDCOLOR}"
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
PORT_PID=$!
echo -e "${GREEN}Port forward pid: $PORT_PID${ENDCOLOR}"
argocd login localhost:8080 --insecure \
    --username admin \
    --password $(kubectl get secret argocd-initial-admin-secret --namespace=argocd --template={{.data.password}} | base64 -d)
argocd repo add $app_repo
argocd app create $app_name \
    --repo $app_repo \
    --path $app_path \
    --dest-namespace $app_namespace \
    --dest-server https://kubernetes.default.svc \
    --directory-recurse \
    --sync-policy automated
kill $PORT_PID
echo -e "${GREEN}DONE!${ENDCOLOR}"
