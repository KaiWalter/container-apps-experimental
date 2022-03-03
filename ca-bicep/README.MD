### clean up priv gateway 

```
RESOURCE_GROUP="ca-kw"
az network private-endpoint delete -g $RESOURCE_GROUP -n pep-priv-gateway
az network application-gateway delete -g $RESOURCE_GROUP -n ca-kw-priv-gateway
az network public-ip delete -g $RESOURCE_GROUP -n ca-kw-priv-gateway-pip
./deploy-stage-2.sh
./test-fapps.sh
```