#!/bin/bash

RESOURCE_GROUP="ca-kw"

for vm in `az vm list -g ${RESOURCE_GROUP} --query [].id -o tsv`; do az vm start --id $vm; done