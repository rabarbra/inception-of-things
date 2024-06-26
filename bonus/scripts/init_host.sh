#!/bin/bash

# Configuration
cluster_name="gitlab"
certs_email="psimonen@student.42wolfsburg.de"
gitlab_domain="app.com"
gitlab_ip="172.29.0.2"

# Colors
GREEN="\e[32m"
ENDCOLOR="\e[0m"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Install Docker
if ! command -v docker &> /dev/null
then
    echo -e "${GREEN}Installing docker${ENDCOLOR}"
    sudo dnf install dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install docker-ce docker-ce-cli containerd.io
    sudo groupadd -f docker
    sudo usermod -aG docker ${USER}
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
    k3d cluster create $cluster_name --k3s-arg '--disable=traefik@server:0' --servers-memory 4000M
fi
echo -e "${GREEN}Cluster nodes:${ENDCOLOR}"
kubectl get nodes

# Install Helm
if ! command -v helm &> /dev/null
then
    echo -e "${GREEN}Installing Helm${ENDCOLOR}"
    sudo dnf install helm
fi

# Install Gitlab
echo -e "${GREEN}Installing GitLab${ENDCOLOR}"
kubectl create namespace gitlab
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 600s \
  --set global.hosts.domain=$gitlab_domain \
  --set global.hosts.externalIP=$gitlab_ip \
  --set certmanager-issuer.email=$certs_email \
  --set certmnager.install=false \
  --set prometheus.install=false \
  --set gitlab-runner.install=false \
  --set global.ingress.configureCertmanager=false \
  --set global.rails.bootsnap.enabled=false \
  --set gitlab.webservice.minReplicas=1 \
  --set gitlab.webservice.maxReplicas=1 \
  --set gitlab.webservice.workerProcesses=0 \
  --set gitlab.webservice.resources.requests.memory=600M \
  --set global.kas.enabled=false \
  --set gitlab.kas.minReplicas=1 \
  --set gitlab.kas.maxReplicas=1 \
  --set gitlab.gitlab-exporter.enabled=false \
  --set gitlab.toolbox.enabled=false \
  --set gitlab.sidekiq.enabled=false \
  --set gitlab.sidekiq.minReplicas=1 \
  --set gitlab.sidekiq.maxReplicas=1 \
  --set gitlab.sidekiq.resources.requests.memory=300M \
  --set gitlab.sidekiq.resources.requests.cpu=60m \
  --set gitlab.gitlab-shell.minReplicas=1 \
  --set gitlab.gitlab-shell.maxReplicas=1 \
  --set registry.hpa.minReplicas=1 \
  --set registry.hpa.maxReplicas=1

echo -e "${GREEN}DONE!${ENDCOLOR}"
