using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using System.IO;
using System.Net.Http;
using System.Threading.Tasks;

namespace fapp1
{
    public static class HttpIngress
    {
        private static HttpClient httpClient = new HttpClient();

        [FunctionName("Health")]
        public static IActionResult Health([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req) => new OkObjectResult("OK");

        [FunctionName("HttpIngress")]
        [return: ServiceBus("%queuename%", Connection = "servicebusconnection")]
        public static async Task<string> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = null)] HttpRequest req)
            => await new StreamReader(req.Body).ReadToEndAsync();

        [FunctionName("Apim-Status")]
        public static async Task<IActionResult> ApimStatus([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "apim-status")] HttpRequest req) => new OkObjectResult(await httpClient.GetAsync("http://ca-kw.internal-api.net:8080/status-0123456789abcdef"));

        [FunctionName("Apim-Internal-Status")]
        public static async Task<IActionResult> ApimInternalStatus([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "apim-internal-status")] HttpRequest req) => new OkObjectResult(await httpClient.GetAsync("http://ca-kw.internal-api.net:8080/internal-status-0123456789abcdef"));
    }
}
