using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace fapp2
{
    public static class QueueIngress
    {
        [FunctionName("QueueIngress")]
        public static void Run(
            [ServiceBusTrigger("%queuename%", Connection = "servicebusconnection")]string payload, ILogger log)
        {
            log.LogInformation($"C# ServiceBus queue trigger function processed message: {payload}");
        }
    }
}
