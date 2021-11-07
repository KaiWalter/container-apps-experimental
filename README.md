# container-apps-experimental

Try container apps with various workloads

## get started

sign in with Azure CLI

```shell
az login --use-device-code
```

switch to the desired subscription

```shell
az account set -s "{subscription-name-or-id}"
```

sign in with Pulumi

```shell
pulumi login
```

## test ca-dotnet sample

> sample transferred from <https://github.com/pulumi/examples/tree/master/azure-cs-containerapps>

deploy sample

```shell
cd ca-dotnet
pulumi up
```

test sample

```shell
curl $(pulumi stack output url)
```

## links

- [VSCode devcontainer setup](https://stackoverflow.com/questions/69870435/how-do-i-add-pulumi-to-my-vscode-net-devcontainer)
- [other vscode-dev-containers features](https://github.com/microsoft/vscode-dev-containers/tree/main/script-library/docs)