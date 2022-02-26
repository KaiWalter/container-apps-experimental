## enable preview features

SubscriptionNotRegisteredForFeature / Subscription /subscriptions/... is not registered for feature PrivateLinkConfigurations required to carry out the requested operation

az feature list --namespace Microsoft.Network --output table | grep Priv

az feature register --name AllowApplicationGatewayPrivateLink --namespace Microsoft.Network
az feature register --name AllowAppGwPublicAndPrivateIpOnSamePort --namespace Microsoft.Network
az provider register -n Microsoft.Network

Microsoft.Network/AllowAppGwPublicAndPrivateIpOnSamePort