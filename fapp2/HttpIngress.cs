using System.IO;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace fapp2
{
    public static class HttpIngress
    {
        [FunctionName("HttpIngress")]
        [return: ServiceBus("%queuename%", Connection = "servicebusconnection")]
        public static async Task<string> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req)
            => await new StreamReader(req.Body).ReadToEndAsync();
    }
}
