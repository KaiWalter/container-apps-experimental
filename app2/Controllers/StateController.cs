using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;

namespace app2.Controllers
{
    [ApiController]
    public class StateController : ControllerBase
    {
        private readonly DaprClient _daprClient;
        private readonly ILogger<StateController> _logger;

        public StateController(DaprClient daprClient, ILogger<StateController> logger)
        {
            _daprClient = daprClient;
            _logger = logger;
        }

        [Route("state")]
        [HttpPost]
        public async Task<ActionResult> Post()
        {
            _logger.LogInformation("Post state");
            await _daprClient.SaveStateAsync("state", "SOURCE", $"Hello from {System.Reflection.Assembly.GetExecutingAssembly().FullName}");
            return Ok();
        }

        [Route("state")]
        [HttpGet]
        public async Task<ActionResult<string>> Get()
        {
            _logger.LogInformation("Get state");
            var state = await _daprClient.GetStateAsync<string>("state", "SOURCE");
            return Ok(state);
        }
    }
}