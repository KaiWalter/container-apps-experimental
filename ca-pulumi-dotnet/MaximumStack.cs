using Pulumi;
using Pulumi.AzureNative.Authorization;
using Pulumi.AzureNative.ContainerRegistry;
using Pulumi.AzureNative.ContainerRegistry.Inputs;
using Pulumi.AzureNative.Insights;
using Pulumi.AzureNative.OperationalInsights;
using Pulumi.AzureNative.OperationalInsights.Inputs;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.ServiceBus;
using Pulumi.AzureNative.ServiceBus.Inputs;
using Pulumi.AzureNative.Storage;
using Pulumi.AzureNative.Web.V20210301;
using Pulumi.AzureNative.Web.V20210301.Inputs;
using Pulumi.AzureNative.LoadTestService;
using Pulumi.AzureNative.LoadTestService.Inputs;
using Pulumi.Docker;
using System;

using ContainerArgs = Pulumi.AzureNative.Web.V20210301.Inputs.ContainerArgs;
using SecretArgs = Pulumi.AzureNative.Web.V20210301.Inputs.SecretArgs;
using SkuName = Pulumi.AzureNative.ServiceBus.SkuName;
using StorageAccountArgs = Pulumi.AzureNative.Storage.StorageAccountArgs;
using Queue = Pulumi.AzureNative.ServiceBus.Queue;
using QueueArgs = Pulumi.AzureNative.ServiceBus.QueueArgs;

class MaximumStack : Stack
{
    public MaximumStack()
    {
        var config = GetClientConfig.InvokeAsync().Result;

        var resourceGroup = new ResourceGroup("rg", new ResourceGroupArgs
        {
            Location = "northeurope",
            ResourceGroupName = "ca-kw",
        });

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

        var appInsights = new Component("appInsights", new ComponentArgs
        {
            ApplicationType = "web",
            Kind = "web",
            ResourceGroupName = resourceGroup.Name,
        });

        var kubeEnv = new KubeEnvironment("env", new KubeEnvironmentArgs
        {
            ResourceGroupName = resourceGroup.Name,
            EnvironmentType = "Managed",
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

        var registry = new Registry("registry", new RegistryArgs
        {
            ResourceGroupName = resourceGroup.Name,
            Sku = new SkuArgs { Name = "Basic" },
            AdminUserEnabled = true
        });

        var credentials = Output.Tuple(resourceGroup.Name, registry.Name).Apply(items =>
            ListRegistryCredentials.InvokeAsync(new ListRegistryCredentialsArgs
            {
                ResourceGroupName = items.Item1,
                RegistryName = items.Item2
            }));
        var adminUsername = credentials.Apply(credentials => credentials.Username);
        var adminPassword = credentials.Apply(credentials => credentials.Passwords[0].Value);

        var sb = new Namespace("sb", new NamespaceArgs
        {
            ResourceGroupName = resourceGroup.Name,
            Sku = new SBSkuArgs
            {
                Name = SkuName.Basic,
                Tier = SkuTier.Basic,
            },
        });

        var sbQueue = new Queue("queue1", new QueueArgs
        {
            ResourceGroupName = resourceGroup.Name,
            NamespaceName = sb.Name,
            MaxSizeInMegabytes = 1024,
        });

        ContainerApp functionApp1 = FunctionContainerApp(
            "fapp1",
            resourceGroup,
            kubeEnv,
            registry,
            adminUsername,
            adminPassword,
            appInsights,
            sb,
            sbQueue);

        ContainerApp functionApp2 = FunctionContainerApp(
            "fapp2",
            resourceGroup,
            kubeEnv,
            registry,
            adminUsername,
            adminPassword,
            appInsights,
            sb,
            sbQueue,
            scaleToQueue: true);

        // generate outputs for testing Function apps
        this.CheckFApp1 = Output.Format($"https://{functionApp1.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}/api/health");
        this.CheckFApp2 = Output.Format($"https://{functionApp2.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}/api/health");
        this.LoadtestFApp1 = Output.Format($"for i in {{1..500}}; do echo $i; curl -X POST -d 'TEST' https://{functionApp1.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}/api/httpingress; done");
        this.LoadtestUrlFApp1 = Output.Format($"{functionApp1.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}");

        // Dapr ASP.NET Core apps
        ContainerApp daprApp1 = DaprContainerApp(
            "app1",
            resourceGroup,
            kubeEnv,
            registry,
            adminUsername,
            adminPassword,
            appInsights,
            storageAccount,
            blobContainer);

        ContainerApp daprApp2 = DaprContainerApp(
            "app2",
            resourceGroup,
            kubeEnv,
            registry,
            adminUsername,
            adminPassword,
            appInsights,
            storageAccount,
            blobContainer);

        // generate outputs for testing Dapr apps
        this.CheckApp1 = Output.Format($"https://{daprApp1.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}/health");
        this.CheckApp2 = Output.Format($"https://{daprApp2.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}/health");
        this.CheckApp1FromApp2 = Output.Format($"https://{daprApp2.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}/health-remote");
        this.CheckApp2FromApp1 = Output.Format($"https://{daprApp1.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}/health-remote");

        // load test service
        var loadtest = new LoadTest("loadtest", new LoadTestArgs
        {
            ResourceGroupName = resourceGroup.Name,
            Description = "Load testing for Container Apps scaling",
            Identity = new SystemAssignedServiceIdentityArgs
            {
                Type = SystemAssignedServiceIdentityType.SystemAssigned,
            },
        });

        // authorize load test owner to user executing deployment
        var rd = GetRoleDefinition.InvokeAsync(new GetRoleDefinitionArgs
        {
            RoleDefinitionId = "45bb0b16-2f0c-4e78-afaa-a07599b003f6", // Load Test Owner
            Scope = $"/subscriptions/{config.SubscriptionId}",
        }).Result;

        var iam = new RoleAssignment("iam-loadtest", new RoleAssignmentArgs
        {
            RoleDefinitionId = rd.Id,
            Scope = resourceGroup.Id,
            PrincipalType = "User",
            PrincipalId = config.ObjectId,
        });
    }

    private static ContainerApp FunctionContainerApp(
        string fappName,
        ResourceGroup resourceGroup,
        KubeEnvironment kubeEnv,
        Registry registry,
        Output<string> adminUsername,
        Output<string> adminPassword,
        Component appInsights,
        Namespace sb,
        Queue sbQueue,
        bool scaleToQueue = false)
    {
        var fapp1Image = new Image(fappName, new ImageArgs
        {
            ImageName = Output.Format($"{registry.LoginServer}/{fappName}:{DateTime.UtcNow.ToString("yyyyMMddhhmmss")}"),
            Build = new DockerBuild { Context = $"../{fappName}" },
            Registry = new ImageRegistry
            {
                Server = registry.LoginServer,
                Username = adminUsername,
                Password = adminPassword
            }
        });

        var containerApp = new ContainerApp(fappName, new ContainerAppArgs
        {
            ResourceGroupName = resourceGroup.Name,
            KubeEnvironmentId = kubeEnv.Id,
            Configuration = new ConfigurationArgs
            {
                ActiveRevisionsMode = ActiveRevisionsMode.Single,
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
                        Name = "pwd",
                        Value = adminPassword
                    },
                    new SecretArgs
                    {
                        Name = "servicebusconnection",
                        Value = GetServiceBusConnectionString(resourceGroup.Name, sb.Name)
                    }
                },
            },
            Template = new TemplateArgs
            {
                Containers =
                {
                    new ContainerArgs
                    {
                        Name = fappName,
                        Image = fapp1Image.ImageName,
                        Env = {
                            new EnvironmentVarArgs
                            {
                                Name = "APPINSIGHTS_INSTRUMENTATIONKEY",
                                Value = appInsights.InstrumentationKey,
                            },
                            new EnvironmentVarArgs
                            {
                                Name = "queuename",
                                Value = sbQueue.Name,
                            },
                            new EnvironmentVarArgs
                            {
                                Name = "servicebusconnection",
                                SecretRef = "servicebusconnection",
                            }
                        }
                    }
                },
                Scale = scaleToQueue
                ? new ScaleArgs // Azure Service Bus Queue scaling
                {
                    MinReplicas = 1,
                    MaxReplicas = 10,
                    Rules = {
                        new ScaleRuleArgs
                        {
                            Name = "queue-rule",
                            Custom = new CustomScaleRuleArgs
                            {
                                Type = "azure-servicebus",
                                Metadata = new InputMap<string>
                                {
                                    { "queueName", sbQueue.Name },
                                    { "messageCount", "100" }
                                },
                                Auth = {
                                    new ScaleRuleAuthArgs
                                    {
                                        TriggerParameter = "connection",
                                        SecretRef = "servicebusconnection"
                                    }
                                },
                            },
                        }
                    }
                }
                : new ScaleArgs // HTTP scaling
                {
                    MinReplicas = 1,
                    MaxReplicas = 10,
                    Rules = {
                        new ScaleRuleArgs
                        {
                            Name = "http-rule",
                            Http = new HttpScaleRuleArgs
                            {
                                Metadata = new InputMap<string>
                                {
                                    {"concurrentRequests", "100"}
                                }
                            }
                        }
                    }
                },
            }
        });
        return containerApp;
    }

    private static ContainerApp DaprContainerApp(
        string appName,
        ResourceGroup resourceGroup,
        KubeEnvironment kubeEnv,
        Registry registry,
        Output<string> adminUsername,
        Output<string> adminPassword,
        Component appInsights,
        StorageAccount storageAccount,
        BlobContainer blobContainer)
    {
        var appImage = new Image(appName, new ImageArgs
        {
            ImageName = Output.Format($"{registry.LoginServer}/{appName}:{DateTime.UtcNow.ToString("yyyyMMddhhmmss")}"),
            Build = new DockerBuild { Context = $"../{appName}" },
            Registry = new ImageRegistry
            {
                Server = registry.LoginServer,
                Username = adminUsername,
                Password = adminPassword
            }
        });

        var containerApp = new ContainerApp(appName, new ContainerAppArgs
        {
            ResourceGroupName = resourceGroup.Name,
            KubeEnvironmentId = kubeEnv.Id,
            Configuration = DaprContainerConfiguration(resourceGroup, storageAccount, registry, adminUsername, adminPassword),
            Template = new TemplateArgs
            {
                Containers =
                {
                    new ContainerArgs
                    {
                        Name = appName,
                        Image = appImage.ImageName,
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
                    AppId = appName,
                    AppPort = 80,
                    Components =
                    {
                        DaprStateComponent(storageAccount, blobContainer),
                    },
                },
            },
        });
        return containerApp;
    }

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


    private static Output<string> GetServiceBusConnectionString(Input<string> resourceGroupName, Input<string> namespaceName)
    {
        var sbKeys = Output.All<string>(resourceGroupName, namespaceName).Apply(t =>
        {
            var resourceGroupName = t[0];
            var namespaceName = t[1];
            return ListNamespaceKeys.InvokeAsync(
                new ListNamespaceKeysArgs
                {
                    ResourceGroupName = resourceGroupName,
                    AuthorizationRuleName = "RootManageSharedAccessKey",
                    NamespaceName = namespaceName
                });
        });
        return sbKeys.Apply(keys =>
        {
            return Output.Create<string>(keys.PrimaryConnectionString);
        });
    }

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

    [Output("loadtestfapp1")]
    public Output<string> LoadtestFApp1 { get; set; }

    [Output("loadtesturlfapp1")]
    public Output<string> LoadtestUrlFApp1 { get; set; }

    [Output("checkfapp1")]
    public Output<string> CheckFApp1 { get; set; }

    [Output("checkfapp2")]
    public Output<string> CheckFApp2 { get; set; }

    [Output("checkapp1")]
    public Output<string> CheckApp1 { get; set; }

    [Output("checkapp2")]
    public Output<string> CheckApp2 { get; set; }
    [Output("checkapp1fromapp2")]
    public Output<string> CheckApp1FromApp2 { get; set; }

    [Output("checkapp2fromapp1")]
    public Output<string> CheckApp2FromApp1 { get; set; }
}