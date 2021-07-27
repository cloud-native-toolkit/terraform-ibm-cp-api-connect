#!/usr/bin/env bash

OUT_FILE="$1"

JQ=$(command -v jq)

if [[ -z "${JQ}" ]]; then
  echo "jq missing. Installing"
  curl -Lo ./jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
  JQ="${PWD}/jq"
fi

STORAGE_CLASS=$(kubectl get storageclass -o json | ${JQ} '.items | .[] | .metadata | select(.["annotations"]["storageclass.beta.kubernetes.io/is-default-class"]=="true") | .name')

echo "Got default storageclass: ${STORAGE_CLASS}"

echo -n "${STORAGE_CLASS}" > "${OUT_FILE}"
