#!/usr/bin/env bash

CRD_LIST="analyticsbackups.analytics.apiconnect.ibm.com,analyticsclusters.analytics.apiconnect.ibm.com,analyticsrestores.analytics.apiconnect.ibm.com,datapowerservices.datapower.ibm.com,gatewayclusters.gateway.apiconnect.ibm.com,managementbackups.management.apiconnect.ibm.com,managementclusters.management.apiconnect.ibm.com,managementrestores.management.apiconnect.ibm.com,natsclusters.nats.io,natsserviceroles.nats.io,natsstreamingclusters.streaming.nats.io,portalbackups.portal.apiconnect.ibm.com,portalclusters.portal.apiconnect.ibm.com,portalrestores.portal.apiconnect.ibm.com"

IFS=',' read -ra CRDS <<< "$CRD_LIST"
for crd in "${CRDS[@]}"; do
  retrycount=10
  while [[ $(kubectl get crd "${crd}" -o jsonpath='{.metadata.name}{"\n"}' | wc -l) -eq 0 ]] && [[ "${retrycount}" -gt 0 ]]; do
    echo "Waiting for crd: ${crd}"
    retrycount=$(( retrycount - 1 ))
    sleep 30
  done

  if [[ $(kubectl get crd "${crd}" -o jsonpath='{.metadata.name}{"\n"}' | wc -l) -eq 0 ]]; then
    echo "Timed out waiting for crd: ${crd}"
    exit 1
  fi
done


