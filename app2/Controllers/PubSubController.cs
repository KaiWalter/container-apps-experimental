using Dapr;
using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using System.Threading.Tasks;

namespace app2.Controllers
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

        [Route("message")]
        [HttpGet]
        public async Task<ActionResult<object>> GetMessage()
        {
            _logger.LogInformation("Get message");
            var state = await _daprClient.GetStateAsync<object>("state", "MESSAGE");
            return Ok(state);
        }

        [Topic("pubsub", "topic1")]
        [Route("pubsub-message")]
        public async Task<ActionResult> PostFromSub([FromBody] object message)
        {
            _logger.LogInformation("Post message into state from subscription");
            await _daprClient.SaveStateAsync("state", "MESSAGE", message);
            return Ok();
        }
    }
}