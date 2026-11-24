#!/usr/bin/env bash
set -euo pipefail

ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD UI : http://localhost:8080 | User: admin | Pass: ${ARGOCD_PWD}"
kubectl port-forward svc/argocd-server -n argocd 8080:80