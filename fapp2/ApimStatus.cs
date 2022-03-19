using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using System.Net.Http;
using System.Threading.Tasks;

namespace fapp2
{
    public class ApimStatus
    {
        private static HttpClient httpClient = new HttpClient();

        [FunctionName("Apim-Status")]
        public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "apim-status")] HttpRequest req) => new OkObjectResult(await httpClient.GetAsync("http://ca-kw.internal-api.net:8080/status-0123456789abcdef"));
    }
}
