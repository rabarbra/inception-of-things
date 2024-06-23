#!/bin/bash
argo=svc/argocd-server
argo_ns=argocd
argo_address="0.0.0.0"
argo_port=8080

app=svc/iot-app
app_ns=dev
app_address="0.0.0.0"
app_port="8888"

pids=/tmp/port_forwardings

# Colors
RED="\e[31m"
GREEN="\e[32m"
END="\e[0m"

if kubectl get $argo -n $argo_ns &> /dev/null
then
    echo -e "${GREEN}Forwardind $argo${END}"
    kubectl port-forward $argo -n $argo_ns $argo_port:443 --address $argo_address &>/dev/null &
    echo $! >> $pids
    echo -e "${GREEN}Access $argo on http://$argo_address:$argo_port${END}"
else
    echo -e "${RED}Service $argo not found!${END}"
fi
if kubectl get $app -n $app_ns &> /dev/null
then
    echo -e "${GREEN}Forwarding $app${END}"
    kubectl port-forward $app -n $app_ns $app_port:$app_port --address $app_address &>/dev/null &
    echo $! >> $pids
    echo -e "${GREEN}Access $app on http://$app_address:$app_port${END}"
else
    echo -e "${RED}Service $app not found!${END}"
fi
