using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using System.Net.Http;
using System.Threading.Tasks;

namespace fapp1
{
    public class ApimInternalStatus
    {
        private static HttpClient httpClient = new HttpClient();

        [FunctionName("Apim-Internal-Status")]
        public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "apim-internal-status")] HttpRequest req) => new OkObjectResult(await httpClient.GetAsync("http://ca-kw.internal-api.net:8080/internal-status-0123456789abcdef"));
    }
}
