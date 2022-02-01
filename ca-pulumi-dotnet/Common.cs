using Pulumi;
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
using SkuName = Pulumi.AzureNative.ServiceBus.SkuName;
using StorageAccountArgs = Pulumi.AzureNative.Storage.StorageAccountArgs;
using Queue = Pulumi.AzureNative.ServiceBus.Queue;
using QueueArgs = Pulumi.AzureNative.ServiceBus.QueueArgs;

public class Common
{
    internal static KubeEnvironment ContainerAppEnvironment(ResourceGroup? resourceGroup, Workspace? workspace, Output<GetSharedKeysResult>? workspaceSharedKeys, Component appInsights) => new KubeEnvironment("env", new KubeEnvironmentArgs
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
        },
        ContainerAppsConfiguration = new ContainerAppsConfigurationArgs
        {
            DaprAIInstrumentationKey = appInsights.InstrumentationKey,
        }
    });

    internal static (Workspace, Output<GetSharedKeysResult>, Component) LoggingResources(ResourceGroup? resourceGroup)
    {
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

        return (workspace, workspaceSharedKeys, appInsights);
    }

    internal static (StorageAccount, BlobContainer) StateStorage(ResourceGroup? resourceGroup)
    {
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

        return (storageAccount, blobContainer);
    }

    internal static (Registry, Output<string>, Output<string>) ContainerRegistryResources(ResourceGroup resourceGroup)
    {
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

        return (registry, adminUsername, adminPassword);
    }

    internal static (Namespace, Queue) ServiceBusResources(ResourceGroup resourceGroup)
    {
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

        return (sb, sbQueue);
    }

    internal static Output<string> GetServiceBusConnectionString(Input<string> resourceGroupName, Input<string> namespaceName)
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

    internal static Output<string> GetStorageKey(Input<string> resourceGroupName, Input<string> accountName)
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
