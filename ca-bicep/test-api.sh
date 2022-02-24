#!/bin/bash

RESOURCE_GROUP="ca-kw"
APIMNAME="ca-kw"
APIMID=`az apim show -n $APIMNAME -g $RESOURCE_GROUP --query id -o tsv`
APIMURL=`az apim show -n $APIMNAME -g $RESOURCE_GROUP --query gatewayUrl -o tsv`
GWURL=`az network public-ip show -n ${APIMNAME}-gateway-pip -g $RESOURCE_GROUP --query dnsSettings.fqdn -o tsv`
GWPORT=`az network application-gateway show -n ${APIMNAME}-gateway -g $RESOURCE_GROUP --query frontendPorts[0].port -o tsv`
SUBKEY=`az rest --method post  --uri ${APIMID}/subscriptions/test-subscription/listSecrets?api-version=2021-08-01 --query primaryKey -o tsv`

curl -s ${GWURL}:${GWPORT}/test/fapp1?subscription-key=$SUBKEY
printf '\n'
curl -s ${GWURL}:${GWPORT}/test/fapp2?subscription-key=$SUBKEY
printf '\n'
