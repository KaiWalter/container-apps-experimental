using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using System.IO;
using System.Threading.Tasks;

namespace fapp2
{
    public static class HttpIngress
    {
        [FunctionName("Health")]
        public static IActionResult Health([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req) => new OkObjectResult("OK");

        [FunctionName("HttpIngress")]
        [return: ServiceBus("%queuename%", Connection = "servicebusconnection")]
        public static async Task<string> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req)
            => await new StreamReader(req.Body).ReadToEndAsync();

        [FunctionName("Apim-Status")]
        public static IActionResult ApimStatus([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "apim-status")] HttpRequest req) => new NoContentResult();

        [FunctionName("Apim-Internal-Status")]
        public static IActionResult ApimInternalStatus([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "apim-internal-status")] HttpRequest req) => new NoContentResult();
    }
}
