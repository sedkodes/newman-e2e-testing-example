#!/bin/bash

# set -eo pipefail

if [ $1 == "all" ]
then 
    echo "Creating tyk-operator-system namespace.."
    kubectl create namespace tyk-operator-system --dry-run=client -o yaml | kubectl apply -f -
    echo "Creating tyk namespace.."
    kubectl create namespace tyk --dry-run=client -o yaml | kubectl apply -f -
    echo "Successfully created all namespaces :)"

    echo "Installing Tyk GW & Redis"
    kubectl apply -f ./part-1-apig/. -n tyk

    CERT_MANAGER_INSTALLED=$(kubectl get all -n cert-manager)
    if [ CERT_MANAGER_INSTALLED == "No resources found in cert-manager namespace." ]
    then
        echo "You must install (and wait to come to life) cert-manager by using './launch.sh install-cert-manager'"
        exit 1
    fi

    echo "Installing Tyk Operator"

    echo "Creating tyk-operator-conf secret in tyk-operator-system namespace.."
    kubectl create secret -n tyk-operator-system generic tyk-operator-conf \
        --from-literal "TYK_AUTH=foo" \
        --from-literal "TYK_ORG=1" \
        --from-literal "TYK_MODE=ce" \
        --from-literal "TYK_URL=http://tyk-svc.tyk.svc:8080" \
        --from-literal "TYK_TLS_INSECURE_SKIP_VERIFY=true"
    kubectl get secret/tyk-operator-conf -n tyk-operator-system -o json | jq '.data'
    echo "Registering tyk-operator CRDs with Kubernetes.."
    curl https://raw.githubusercontent.com/TykTechnologies/tyk-operator/master/helm/crds/crds.yaml | kubectl apply -f -
    echo "Installing tyk-operator in tyk-operator-system namespace.."
    helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/
    helm repo update
    helm install tyk-operator tyk-helm/tyk-operator -n tyk-operator-system
    echo "Successfully installed the tyk stack!"
    exit 0

elif [ $1 == "all-down" ]
then 
    echo "Deleting all resources"
    kubectl delete crd apidefinitions.tyk.tyk.io
    kubectl delete ns tyk
    kubectl delete ns tyk-operator-system
    kubectl delete ns apps
    exit 0
elif [ $1 == "install-cert-manager" ]
then 
    echo "Installing cert manager.."
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.3/cert-manager.yaml
    echo "Successfully installed cert-manager. Use './launch.sh status-cert-manager' to see it's status :)"
    exit 0
elif [ $1 == "delete-cert-manager" ]
then
    echo "Deleting cert manager.."
    kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.0.3/cert-manager.yaml
    echo "Successfully delete cert-manager"
    exit 0
else 
    echo "Error: Need valid first argument: up, down, pf, pf-gateway or pf-control"
    exit 1
fi