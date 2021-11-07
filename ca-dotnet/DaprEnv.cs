using Pulumi;
using Pulumi.AzureNative.OperationalInsights;
using Pulumi.AzureNative.OperationalInsights.Inputs;
using Pulumi.AzureNative.Storage;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.Web.V20210301;
using Pulumi.AzureNative.Web.V20210301.Inputs;
using ContainerArgs = Pulumi.AzureNative.Web.V20210301.Inputs.ContainerArgs;
using SecretArgs = Pulumi.AzureNative.Web.V20210301.Inputs.SecretArgs;
using StorageAccountArgs = Pulumi.AzureNative.Storage.StorageAccountArgs;

class DaprEnv : Stack
{
    public DaprEnv()
    {
        var resourceGroup = new ResourceGroup("rg");

        var storageAccount = new StorageAccount("sa", new StorageAccountArgs
        {
            ResourceGroupName = resourceGroup.Name,
            Sku = new Pulumi.AzureNative.Storage.Inputs.SkuArgs
            {
                Name = Pulumi.AzureNative.Storage.SkuName.Standard_LRS,
            },
            Kind = Pulumi.AzureNative.Storage.Kind.StorageV2,
        });

        var blobContainer = new BlobContainer("blobContainer", new BlobContainerArgs
        {
            AccountName = storageAccount.Name,
            ResourceGroupName = resourceGroup.Name,
            ContainerName = "state",
        });

        var workspace = new Workspace("loganalytics", new WorkspaceArgs
        {
            ResourceGroupName = resourceGroup.Name,
            Sku = new WorkspaceSkuArgs { Name = "PerGB2018" },
            RetentionInDays = 30,
        });

        var workspaceSharedKeys = Output.Tuple(resourceGroup.Name, workspace.Name).Apply(items =>
            GetSharedKeys.InvokeAsync(new GetSharedKeysArgs
            {
                ResourceGroupName = items.Item1,
                WorkspaceName = items.Item2,
            }));

        var kubeEnv = new KubeEnvironment("env", new KubeEnvironmentArgs
        {
            ResourceGroupName = resourceGroup.Name,
            Type = "Managed",
            AppLogsConfiguration = new AppLogsConfigurationArgs
            {
                Destination = "log-analytics",
                LogAnalyticsConfiguration = new LogAnalyticsConfigurationArgs
                {
                    CustomerId = workspace.CustomerId,
                    SharedKey = workspaceSharedKeys.Apply(r => r.PrimarySharedKey)
                }
            }
        });

        var containerNodeApp = new ContainerApp("nodeapp", new ContainerAppArgs
        {
            ResourceGroupName = resourceGroup.Name,
            KubeEnvironmentId = kubeEnv.Id,
            Configuration = new ConfigurationArgs
            {
                Ingress = new IngressArgs
                {
                    External = true,
                    TargetPort = 3000
                },
                Secrets =
                {
                    new SecretArgs
                    {
                        Name = "storage-key",
                        Value = GetStorageKey(resourceGroup.Name, storageAccount.Name)
                    }
                },
            },
            Template = new TemplateArgs
            {
                Containers =
                {
                    new ContainerArgs
                    {
                        Name = "hello-k8s-node",
                        Image = "dapriosamples/hello-k8s-node:latest",
                        Resources = new ContainerResourcesArgs
                        {
                            Memory = "1Gi",
                            Cpu = 0.5,
                        }
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
                    AppId = "nodeapp",
                    AppPort = 3000,
                    Components =
                    {
                        new DaprComponentArgs
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
                        }

                    }
                }
            }
        });

        var containerPythonApp = new ContainerApp("pythonapp", new ContainerAppArgs
        {
            ResourceGroupName = resourceGroup.Name,
            KubeEnvironmentId = kubeEnv.Id,
            Template = new TemplateArgs
            {
                Containers =
                {
                    new ContainerArgs
                    {
                        Name = "hello-k8s-python",
                        Image = "dapriosamples/hello-k8s-python:latest",
                        Resources = new ContainerResourcesArgs
                        {
                            Memory = "1Gi",
                            Cpu = 0.5,
                        }
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
                    AppId = "pythonapp",
                }
            }
        });

        this.Url = Output.Format($"https://{containerNodeApp.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}");
    }

    [Output("url")]
    public Output<string> Url { get; set; }

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