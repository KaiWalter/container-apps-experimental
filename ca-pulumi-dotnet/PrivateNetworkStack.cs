using Pulumi;
using Pulumi.AzureNative.Compute;
using Pulumi.AzureNative.Compute.Inputs;
using Pulumi.AzureNative.ContainerRegistry;
using Pulumi.AzureNative.Insights;
using Pulumi.AzureNative.Network;
using Pulumi.AzureNative.Network.Inputs;
using Pulumi.AzureNative.Resources;
using Pulumi.AzureNative.ServiceBus;
using Pulumi.AzureNative.App.V20220101Preview;
using Pulumi.AzureNative.App.V20220101Preview.Inputs;
using Pulumi.Docker;
using System;

using ContainerArgs = Pulumi.AzureNative.App.V20220101Preview.Inputs.ContainerArgs;
using Image = Pulumi.Docker.Image;
using ImageArgs = Pulumi.Docker.ImageArgs;
using NetworkProfileArgs = Pulumi.AzureNative.Compute.Inputs.NetworkProfileArgs;
using PublicIPAddressSkuArgs = Pulumi.AzureNative.Compute.Inputs.PublicIPAddressSkuArgs;
using SecretArgs = Pulumi.AzureNative.App.V20220101Preview.Inputs.SecretArgs;
using SshPublicKeyArgs = Pulumi.AzureNative.Compute.Inputs.SshPublicKeyArgs;
using SubnetArgs = Pulumi.AzureNative.Network.SubnetArgs;
using SubResourceArgs = Pulumi.AzureNative.Compute.Inputs.SubResourceArgs;
using SubResourceArgsVn = Pulumi.AzureNative.Network.Inputs.SubResourceArgs;

class PrivateNetworkStack : Stack
{
    private const string RESOURCE_GROUP_NAME = "ca-kw";
    private const string JUMP_VM_NAME = "ca-jump";
    private const string JUMP_VM_ADMIN_NAME = "ca";

    public PrivateNetworkStack()
    {
        var config = new Pulumi.Config();
        var sshPubKey = config.Require("sshpubkey");

        var resourceGroup = new ResourceGroup("rg", new ResourceGroupArgs
        {
            Location = "northeurope",
            ResourceGroupName = RESOURCE_GROUP_NAME,
        });

        var vnet = new VirtualNetwork($"vnet", new VirtualNetworkArgs
        {
            ResourceGroupName = resourceGroup.Name,
            AddressSpace = new AddressSpaceArgs
            {
                AddressPrefixes = { "10.0.0.0/16" },
            }
        });

        var subnetBackend = new Subnet($"subnet-backend", new SubnetArgs
        {
            ResourceGroupName = resourceGroup.Name,
            AddressPrefix = "10.0.0.0/21",
            VirtualNetworkName = vnet.Name,
        });

        var subnetCP = new Subnet($"subnet-cp", new SubnetArgs
        {
            ResourceGroupName = resourceGroup.Name,
            AddressPrefix = "10.0.8.0/21",
            VirtualNetworkName = vnet.Name,
        });

        var subnetJump = new Subnet($"subnet-jump", new SubnetArgs
        {
            ResourceGroupName = resourceGroup.Name,
            AddressPrefix = "10.0.16.0/24",
            VirtualNetworkName = vnet.Name,
        });

        var virtualMachine = new VirtualMachine("virtualMachine", new VirtualMachineArgs
        {
            ResourceGroupName = resourceGroup.Name,
            HardwareProfile = new HardwareProfileArgs
            {
                VmSize = "Standard_D2s_v3",
            },
            NetworkProfile = new NetworkProfileArgs
            {
                NetworkApiVersion = "2020-11-01",
                NetworkInterfaceConfigurations =
                {
                    new VirtualMachineNetworkInterfaceConfigurationArgs
                    {
                        DeleteOption = "Delete",
                        IpConfigurations =
                        {
                            new VirtualMachineNetworkInterfaceIPConfigurationArgs
                            {
                                Name = $"{JUMP_VM_NAME}-ip",
                                Primary = true,
                                PublicIPAddressConfiguration = new VirtualMachinePublicIPAddressConfigurationArgs
                                {
                                    DeleteOption = "Detach",
                                    Name = $"{JUMP_VM_NAME}-pip",
                                    PublicIPAllocationMethod = "Static",
                                    Sku = new PublicIPAddressSkuArgs
                                    {
                                        Name = "Basic",
                                        Tier = "Regional",
                                    },
                                },
                                PrivateIPAddressVersion = IPVersions.IPv4,
                                Subnet = new SubResourceArgs
                                {
                                    Id = subnetJump.Id,
                                }
                            },
                        },
                        Name = $"{JUMP_VM_NAME}-nic",
                        Primary = true,
                    },
                },
            },
            OsProfile = new OSProfileArgs
            {
                AdminUsername = JUMP_VM_ADMIN_NAME,
                ComputerName = JUMP_VM_NAME,
                LinuxConfiguration = new LinuxConfigurationArgs
                {
                    DisablePasswordAuthentication = true,
                    Ssh = new SshConfigurationArgs
                    {
                        PublicKeys =
                        {
                            new SshPublicKeyArgs
                            {
                                KeyData = sshPubKey,
                                Path = $"/home/{JUMP_VM_ADMIN_NAME}/.ssh/authorized_keys",
                            },
                        },
                    },
                },
            },
            StorageProfile = new StorageProfileArgs
            {
                ImageReference = new ImageReferenceArgs
                {
                    Offer = "UbuntuServer",
                    Publisher = "Canonical",
                    Sku = "18.04-LTS",
                    Version = "latest",
                },
                OsDisk = new OSDiskArgs
                {
                    Caching = CachingTypes.ReadWrite,
                    CreateOption = "FromImage",
                    ManagedDisk = new ManagedDiskParametersArgs
                    {
                        StorageAccountType = "Premium_LRS",
                    },
                    // Name = "myVMosdisk",
                },
            },
            VmName = JUMP_VM_NAME,
        });

        var (workspace, workspaceSharedKeys, appInsights) = Common.LoggingResources(resourceGroup);

        var containerAppEnv = new ManagedEnvironment("env", new ManagedEnvironmentArgs
        {
            VnetConfiguration = new VnetConfigurationArgs
            {
                InfrastructureSubnetId = subnetCP.Id,
                RuntimeSubnetId = subnetBackend.Id,
            },
            ResourceGroupName = resourceGroup.Name,
            AppLogsConfiguration = new AppLogsConfigurationArgs
            {
                Destination = "log-analytics",
                LogAnalyticsConfiguration = new LogAnalyticsConfigurationArgs
                {
                    CustomerId = workspace.CustomerId,
                    SharedKey = workspaceSharedKeys.Apply(r => r.PrimarySharedKey)
                }
            },
        });

        var privateZone = new PrivateZone("privateZone", new PrivateZoneArgs
        {
            Location = "Global",
            ResourceGroupName = resourceGroup.Name,
            PrivateZoneName = containerAppEnv.DefaultDomain,
        });

        var privateRecordSet = new PrivateRecordSet("privateRecordSet", new PrivateRecordSetArgs
        {
            ResourceGroupName = resourceGroup.Name,
            ARecords =
            {
                new ARecordArgs
                {
                    Ipv4Address = containerAppEnv.StaticIp,
                },
            },
            PrivateZoneName = privateZone.Name,
            RecordType = "A",
            RelativeRecordSetName = "*",
            Ttl = 3600,
        });

        var virtualNetworkLink = new VirtualNetworkLink("virtualNetworkLink", new VirtualNetworkLinkArgs
        {
            Location = "Global",
            ResourceGroupName = resourceGroup.Name,
            PrivateZoneName = privateZone.Name,
            RegistrationEnabled = false,
            VirtualNetwork = new SubResourceArgsVn
            {
                Id = vnet.Id,
            },
        });

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

        this.Url = Output.Format($"https://{functionApp1.Configuration.Apply(c => c.Ingress).Apply(i => i.Fqdn)}");
    }

    private static ContainerApp FunctionContainerApp(
        string fappName,
        ResourceGroup resourceGroup,
        ManagedEnvironment kubeEnv,
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
            Name = fappName,
            ResourceGroupName = resourceGroup.Name,
            ManagedEnvironmentId = kubeEnv.Id,
            Configuration = new ConfigurationArgs
            {
                ActiveRevisionsMode = ActiveRevisionsMode.Single,
                Ingress = new IngressArgs
                {
                    External = false,
                    TargetPort = 80,
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

    [Output("url")]
    public Output<string> Url { get; set; }
}