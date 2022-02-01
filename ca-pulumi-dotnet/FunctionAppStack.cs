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
using Pulumi.AzureNative.Web.V20210301;
using Pulumi.AzureNative.Web.V20210301.Inputs;
using Pulumi.AzureNative.LoadTestService;
using Pulumi.AzureNative.LoadTestService.Inputs;
using Pulumi.Docker;
using System;

using ContainerArgs = Pulumi.AzureNative.Web.V20210301.Inputs.ContainerArgs;
using SecretArgs = Pulumi.AzureNative.Web.V20210301.Inputs.SecretArgs;
using SkuName = Pulumi.AzureNative.ServiceBus.SkuName;

class FunctionAppStack : Stack
{
    public FunctionAppStack()
    {
        var config = GetClientConfig.InvokeAsync().Result;

        var resourceGroup = new ResourceGroup("rg", new ResourceGroupArgs
        {
            Location = "northeurope",
            ResourceGroupName = "ca-kw",
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

        ContainerApp containerApp1 = FunctionContainerApp(
            "fapp1",
            resourceGroup,
            kubeEnv,
            registry,
            adminUsername,
            adminPassword,
            appInsights,
            sb,
            sbQueue);

        ContainerApp containerApp2 = FunctionContainerApp(
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

        this.LoadtestFApp1 = Output.Format($"for i in {{1..500}}; do echo $i; curl -X POST -d 'TEST' https://{containerApp1.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}/api/httpingress; done");
        this.UrlFApp1 = Output.Format($"{containerApp1.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}");
        this.UrlFApp2 = Output.Format($"{containerApp2.Configuration.Apply(c => c!.Ingress).Apply(i => i!.Fqdn)}");

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
        var fappImage = new Image(fappName, new ImageArgs
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
                        Image = fappImage.ImageName,
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

    [Output("loadtestfapp1")]
    public Output<string> LoadtestFApp1 { get; set; }

    [Output("urlfapp1")]
    public Output<string> UrlFApp1 { get; set; }

    [Output("urlfapp2")]
    public Output<string> UrlFApp2 { get; set; }
}