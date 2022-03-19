using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;

namespace fapp3
{
    public class HttpIngress
    {
        [FunctionName("Health")]
        public IActionResult Health([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req) => new OkObjectResult("OK");

        [FunctionName("HttpIngress")]
        [return: ServiceBus("%queuename%", Connection = "servicebusconnection")]
        public async Task<string> PostIngress(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest req)
            => await new StreamReader(req.Body).ReadToEndAsync();
    }
}
