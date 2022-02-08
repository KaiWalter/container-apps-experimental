#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw"
ACRNAME=$(az acr list -g $RESOURCE_GROUP --query [0].name -o tsv)
ACRLOGINSERVER=$(az acr show -n $ACRNAME -g $RESOURCE_GROUP --query loginServer -o tsv)
ACRPASSWORD=$(az acr credential show -n $ACRNAME -g $RESOURCE_GROUP --query passwords[0].value -o tsv)

declare -a apps=("fapp1" "fapp2")
timestamp=$(date +%s)

ENVID=`az containerapp env show -g $RESOURCE_GROUP --name $ENVIRONMENTNAME --query id -o tsv --only-show-errors`
INSTKEY=`az monitor app-insights component show -g $RESOURCE_GROUP -a appins-$RESOURCE_GROUP --query instrumentationKey -o tsv`
SBCONN=`az servicebus namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name sb-$RESOURCE_GROUP --name RootManageSharedAccessKey --query primaryConnectionString -o tsv`

mkdir -p /tmp/deployment
rm /tmp/deployment/*

cat <<EOF >/tmp/deployment/env.json
[
    {
        "name": "servicebusconnection",
        "secretRef": "servicebusconnection",
        "value": null
    },
    {
        "name": "queuename",
        "secretRef": null,
        "value": "queue1"
    },
    {
        "name": "APPINSIGHTS_INSTRUMENTATIONKEY",
        "secretRef": null,
        "value": "$INSTKEY"
    }
]
EOF

for app in "${apps[@]}"
do
    echo "$app"

    if [ $1 = 'skipbuild' ]; then
        timestamp=`az acr repository show-tags -n $ACRNAME --repository $app --top 1 --orderby time_desc -o tsv`
    else
        dotnet publish ../$app/$app.csproj

        az acr build -t $ACRLOGINSERVER/$app:$timestamp -r $ACRNAME ../$app
    fi

    if [ $app = 'app1' ]; then
        scaleby=Http
    else
        scaleby=Queue
    fi

    az deployment group create -n $app \
    -g $RESOURCE_GROUP \
    --template-file ./fapp.bicep \
    -p  name=$app \
        containerAppEnvironmentId=$ENVID \
        containerImage=$ACRLOGINSERVER/$app:$timestamp \
        containerPort=80 \
        registry=$ACRLOGINSERVER \
        registryUsername=$ACRNAME \
        registryPassword="$ACRPASSWORD" \
        serviceBusConnection="$SBCONN" \
        useExternalIngress=true \
        envVars=@/tmp/deployment/env.json \
        scaleBy=$scaleby

done

for app in "${apps[@]}"
do
    echo https://$(az containerapp show -n $app -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors)/api/health
done

