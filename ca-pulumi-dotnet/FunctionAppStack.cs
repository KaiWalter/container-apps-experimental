using Pulumi;
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
using Pulumi.Docker;
using System;

using ContainerArgs = Pulumi.AzureNative.Web.V20210301.Inputs.ContainerArgs;
using SecretArgs = Pulumi.AzureNative.Web.V20210301.Inputs.SecretArgs;
using SkuName = Pulumi.AzureNative.ServiceBus.SkuName;

class FunctionAppStack : Stack
{
    public FunctionAppStack()
    {
        var resourceGroup = new ResourceGroup("rg");

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
            sbQueue);

        this.UrlApp1 = Output.Format($"https://{containerApp1.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}");
        this.UrlApp2 = Output.Format($"https://{containerApp2.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}");
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
        Queue sbQueue)
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
                Scale = new ScaleArgs
                {
                    MaxReplicas = 3,
                    MinReplicas = 1,
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

    [Output("urlapp1")]
    public Output<string> UrlApp1 { get; set; }

    [Output("urlapp2")]
    public Output<string> UrlApp2 { get; set; }
}