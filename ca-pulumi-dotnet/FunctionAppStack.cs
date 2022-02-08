using Pulumi;
using Pulumi.AzureNative.Authorization;
using Pulumi.AzureNative.ContainerRegistry;
using Pulumi.AzureNative.Insights;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.ServiceBus;
using Pulumi.AzureNative.Web.V20210301;
using Pulumi.AzureNative.Web.V20210301.Inputs;
using Pulumi.AzureNative.LoadTestService;
using Pulumi.AzureNative.LoadTestService.Inputs;
using Pulumi.Docker;
using System;

using ContainerArgs = Pulumi.AzureNative.Web.V20210301.Inputs.ContainerArgs;
using SecretArgs = Pulumi.AzureNative.Web.V20210301.Inputs.SecretArgs;

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

        var (workspace, workspaceSharedKeys, appInsights) = Common.LoggingResources(resourceGroup);

        var containerAppEnv = Common.ContainerAppEnvironment(resourceGroup, workspace, workspaceSharedKeys, appInsights);

        var (registry, adminUsername, adminPassword) = Common.ContainerRegistryResources(resourceGroup);

        var (sb, sbQueue) = Common.ServiceBusResources(resourceGroup);

        ContainerApp functionApp1 = FunctionContainerApp(
            "fapp1",
            resourceGroup,
            containerAppEnv,
            registry,
            adminUsername,
            adminPassword,
            appInsights,
            sb,
            sbQueue);

        ContainerApp functionApp2 = FunctionContainerApp(
            "fapp2",
            resourceGroup,
            containerAppEnv,
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
            Name = fappName,
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
                        Value = Common.GetServiceBusConnectionString(resourceGroup.Name, sb.Name)
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
                            },
                            new EnvironmentVarArgs
                            {
                                Name = "AzureFunctionsWebHost__hostId",
                                Value = Guid.NewGuid().ToString().Replace("-", ""),
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

    [Output("loadtestfapp1")]
    public Output<string> LoadtestFApp1 { get; set; }

    [Output("loadtesturlfapp1")]
    public Output<string> LoadtestUrlFApp1 { get; set; }

    [Output("checkfapp1")]
    public Output<string> CheckFApp1 { get; set; }

    [Output("checkfapp2")]
    public Output<string> CheckFApp2 { get; set; }

}