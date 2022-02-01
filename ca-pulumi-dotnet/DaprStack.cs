using Pulumi;
using Pulumi.AzureNative.ContainerRegistry;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.Storage;
using Pulumi.AzureNative.Web.V20210301;
using Pulumi.AzureNative.Web.V20210301.Inputs;
using Pulumi.Docker;
using ContainerArgs = Pulumi.AzureNative.Web.V20210301.Inputs.ContainerArgs;
using SecretArgs = Pulumi.AzureNative.Web.V20210301.Inputs.SecretArgs;

class DaprStack : Stack
{
    public DaprStack()
    {
        var resourceGroup = new ResourceGroup("rg");

        var (storageAccount, blobContainer) = Common.StateStorage(resourceGroup);

        var (workspace, workspaceSharedKeys, appInsights) = Common.LoggingResources(resourceGroup);

        var containerAppEnv = Common.ContainerAppEnvironment(resourceGroup, workspace, workspaceSharedKeys, appInsights);

        var (registry, adminUsername, adminPassword) = Common.ContainerRegistryResources(resourceGroup);

        var customApp1Image = "app1";
        var myApp1Image = new Image(customApp1Image, new ImageArgs
        {
            ImageName = Output.Format($"{registry.LoginServer}/{customApp1Image}:v1.0.0"),
            Build = new DockerBuild { Context = $"../{customApp1Image}" },
            Registry = new ImageRegistry
            {
                Server = registry.LoginServer,
                Username = adminUsername,
                Password = adminPassword
            }
        });

        var customApp2Image = "app2";
        var myApp2Image = new Image(customApp2Image, new ImageArgs
        {
            ImageName = Output.Format($"{registry.LoginServer}/{customApp2Image}:v1.0.0"),
            Build = new DockerBuild { Context = $"../{customApp2Image}" },
            Registry = new ImageRegistry
            {
                Server = registry.LoginServer,
                Username = adminUsername,
                Password = adminPassword
            }
        });

        var containerApp1 = new ContainerApp("app1", new ContainerAppArgs
        {
            ResourceGroupName = resourceGroup.Name,
            KubeEnvironmentId = containerAppEnv.Id,
            Configuration = DaprContainerConfiguration(resourceGroup, storageAccount, registry, adminUsername, adminPassword),
            Template = new TemplateArgs
            {
                Containers =
                {
                    new ContainerArgs
                    {
                        Name = "app1",
                        Image = myApp1Image.ImageName,
                        Resources = new ContainerResourcesArgs
                        {
                            Memory = "1Gi",
                            Cpu = 0.5,
                        },
                    }
                },
                Scale = new ScaleArgs
                {
                    MaxReplicas = 1,
                    MinReplicas = 1,
                },
                Dapr = new DaprArgs
                {
                    Enabled = true,
                    AppId = "app1",
                    AppPort = 80,
                    Components =
                    {
                        DaprStateComponent(storageAccount, blobContainer),
                    },
                },
            },
        });

        var containerApp2 = new ContainerApp("app2", new ContainerAppArgs
        {
            ResourceGroupName = resourceGroup.Name,
            KubeEnvironmentId = containerAppEnv.Id,
            Configuration = DaprContainerConfiguration(resourceGroup, storageAccount, registry, adminUsername, adminPassword),
            Template = new TemplateArgs
            {
                Containers =
                {
                    new ContainerArgs
                    {
                        Name = "app2",
                        Image = myApp2Image.ImageName,
                        Resources = new ContainerResourcesArgs
                        {
                            Memory = "1Gi",
                            Cpu = 0.5,
                        },
                    }
                },
                Scale = new ScaleArgs
                {
                    MaxReplicas = 1,
                    MinReplicas = 1,
                },
                Dapr = new DaprArgs
                {
                    Enabled = true,
                    AppId = "app2",
                    AppPort = 80,
                    Components =
                    {
                        DaprStateComponent(storageAccount, blobContainer),
                    },
                },
            }
        });

        this.UrlApp1 = Output.Format($"https://{containerApp1.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}");
        this.UrlApp2 = Output.Format($"https://{containerApp2.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}");
    }

    [Output("urlapp1")]
    public Output<string> UrlApp1 { get; set; }

    [Output("urlapp2")]
    public Output<string> UrlApp2 { get; set; }

    private static ConfigurationArgs DaprContainerConfiguration(ResourceGroup resourceGroup, StorageAccount storageAccount, Registry registry, Output<string> adminUsername, Output<string> adminPassword)
    {
        return new ConfigurationArgs
        {
            Ingress = new IngressArgs
            {
                External = true,
                TargetPort = 80
            },
            Registries =
                {
                    new RegistryCredentialsArgs
                    {
                        Server = registry.LoginServer,
                        Username = adminUsername,
                        PasswordSecretRef = "pwd",
                    }
                },
            Secrets =
                {
                    new SecretArgs
                    {
                        Name = "storage-key",
                        Value = GetStorageKey(resourceGroup.Name, storageAccount.Name)
                    },
                    new SecretArgs
                    {
                        Name = "pwd",
                        Value = adminPassword
                    },
                },
        };
    }

    private static DaprComponentArgs DaprStateComponent(StorageAccount storageAccount, BlobContainer blobContainer)
        => new DaprComponentArgs
        {
            Name = "statestore",
            Type = "state.azure.blobstorage",
            Version = "v1",
            Metadata =
                            {
                                new DaprMetadataArgs
                                {
                                    Name = "accountName",
                                    Value = storageAccount.Name,
                                },
                                new DaprMetadataArgs
                                {
                                    Name = "accountKey",
                                    SecretRef = "storage-key",
                                },
                                new DaprMetadataArgs
                                {
                                    Name = "containerName",
                                    Value = blobContainer.Name,
                                },
                            }
        };

    private static Output<string> GetStorageKey(Input<string> resourceGroupName, Input<string> accountName)
    {
        // Retrieve the primary storage account key.
        var storageAccountKeys = Output.All<string>(resourceGroupName, accountName).Apply(t =>
        {
            var resourceGroupName = t[0];
            var accountName = t[1];
            return ListStorageAccountKeys.InvokeAsync(
                new ListStorageAccountKeysArgs
                {
                    ResourceGroupName = resourceGroupName,
                    AccountName = accountName
                });
        });
        return storageAccountKeys.Apply(keys =>
        {
            var primaryStorageKey = keys.Keys[0].Value;

            // Build the connection string to the storage account.
            return Output.Create<string>(primaryStorageKey);
        });
    }
}