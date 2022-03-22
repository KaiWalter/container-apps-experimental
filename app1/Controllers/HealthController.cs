using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using System;
using System.Net.Http;
using System.Threading.Tasks;

namespace app1.Controllers
{
    [ApiController]
    public class HealthController : ControllerBase
    {
        private readonly DaprClient _daprClient;

        public HealthController(DaprClient daprClient) => _daprClient = daprClient;

        [Route("health")]
        [HttpGet]
        public IActionResult Get()
        {
            var status = new
            {
                status = "OK",
                assembly = System.Reflection.Assembly.GetExecutingAssembly().FullName,
                instrumentationKey = Environment.GetEnvironmentVariable("INSTRUMENTATIONKEY"),
            };

            return Ok(status);
        }

        [Route("health-remote")]
        [HttpGet]
        public async Task<IActionResult> App2Get()
        {
            var status = await _daprClient.InvokeMethodAsync<object>(HttpMethod.Get, "app2", "health");

            return Ok(status);
        }
    }
}
