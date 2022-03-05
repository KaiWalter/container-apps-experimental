#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"
ACRNAME=$(az acr list -g $RESOURCE_GROUP --query [0].name -o tsv)
ACRLOGINSERVER=$(az acr show -n $ACRNAME -g $RESOURCE_GROUP --query loginServer -o tsv)
ACRPASSWORD=$(az acr credential show -n $ACRNAME -g $RESOURCE_GROUP --query passwords[0].value -o tsv)

declare -a apps=("app1" "app2")
timestamp=$(date +%s)

for app in "${apps[@]}"
do
    echo "$app"

    dotnet publish ../$app/$app.csproj

    az acr build -t $ACRLOGINSERVER/$app:$timestamp -r $ACRNAME ../$app

    CONTAINERAPPID=$(az containerapp list -g $RESOURCE_GROUP --query "[?name == '$app'].id" -o tsv)

    if [ "$CONTAINERAPPID" = "" ]; then

        az containerapp create -e $ENVIRONMENTNAME -g $RESOURCE_GROUP \
            -i $ACRLOGINSERVER/$app:$timestamp \
            --registry-login-server $ACRLOGINSERVER \
            --registry-password "$ACRPASSWORD" \
            --registry-username $ACRNAME \
            -n $app \
            --cpu 0.5 --memory 1Gi \
            --location $LOCATION  \
            --ingress external \
            --max-replicas 10 --min-replicas 1 \
            --target-port 80 \
            --enable-dapr --dapr-app-id $app --dapr-app-port 80

    else

        az containerapp update -g $RESOURCE_GROUP \
            -i $ACRLOGINSERVER/$app:$timestamp \
            --registry-login-server $ACRLOGINSERVER \
            --registry-password "$ACRPASSWORD" \
            --registry-username $ACRNAME \
            -n $app \
            --cpu 0.5 --memory 1Gi \
            --ingress external \
            --max-replicas 10 --min-replicas 1 \
            --target-port 80 \
            --enable-dapr --dapr-app-id $app --dapr-app-port 80

    fi

done

for app in "${apps[@]}"
do
    echo https://$(az containerapp show -n $app -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv)/health
    echo https://$(az containerapp show -n $app -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv)/health-remote
done

