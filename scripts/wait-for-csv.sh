#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

retries=10
while [[ $(kubectl get csv -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -c "${NAME}") -eq 0 ]] && \
 [[ "${retries}" -gt 0 ]]; do
  echo "Waiting for ${NAME} csv to be created"
  retries=$(( retries - 1))
  sleep 30
done

if [[ $(kubectl get csv -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -c "${NAME}") -eq 0 ]]; then
  echo "Timed out waiting for ${NAME} csv to be created"
  exit 1
fi
