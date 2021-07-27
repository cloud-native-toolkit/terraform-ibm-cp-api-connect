#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

DEPLOYMENT_NAME=$(kubectl get deployment -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep "${NAME}" | head -1)

if [[ -z "${DEPLOYMENT_NAME}" ]]; then
  echo "Unable to find deployment: ${NAME}"
  exit 1
fi

kubectl rollout status "deployment/${DEPLOYMENT_NAME}" -w
