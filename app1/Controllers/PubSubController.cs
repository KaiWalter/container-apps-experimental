using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;

namespace app1.Controllers
{
    [ApiController]
    public class PubSubController : ControllerBase
    {
        private readonly DaprClient _daprClient;
        private readonly ILogger<PubSubController> _logger;

        public PubSubController(DaprClient daprClient, ILogger<PubSubController> logger)
        {
            _daprClient = daprClient;
            _logger = logger;
        }

        [Route("pub")]
        [HttpPost]
        public async Task<ActionResult> Post([FromBody] object message)
        {
            _logger.LogInformation("Publish message");
            await _daprClient.PublishEventAsync<object>("pubsub", "topic1", message);
            return Ok();
        }
    }
}