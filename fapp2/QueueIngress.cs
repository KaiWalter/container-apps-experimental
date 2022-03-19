using System;
using System.Threading;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace fapp2
{
    public class QueueIngress
    {
        Random rnd = new Random();

        [FunctionName("QueueIngress")]
        public void Run(
            [ServiceBusTrigger("%queuename%", Connection = "servicebusconnection")] string payload, ILogger log)
        {
            log.LogInformation($"C# ServiceBus queue trigger function processed message: {payload}");
            Thread.Sleep(100 * rnd.Next(5, 100));
        }
    }
}
