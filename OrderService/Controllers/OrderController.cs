using Microsoft.AspNetCore.Mvc;
using OrderService.Models;
using OrderService.Services;

namespace OrderService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ILogger<OrdersController> _logger;
    private readonly IOrderBusinessService _orderService;

    public OrdersController(
        ILogger<OrdersController> logger,
        IOrderBusinessService orderService)
    {
        _logger = logger;
        _orderService = orderService;
    }

    [HttpGet]
    public ActionResult<IEnumerable<Order>> GetAll()
    {
        _logger.LogInformation("Retrieving all orders");
        var orders = _orderService.GetAllOrders();
        _logger.LogInformation("Retrieved {Count} orders", orders.Count());
        return Ok(orders);
    }

    [HttpGet("{id}")]
    public ActionResult<Order> GetById(string id)
    {
        _logger.LogInformation("Retrieving order {OrderId}", id);

        var order = _orderService.GetOrderById(id);
        if (order == null)
        {
            _logger.LogWarning("Order {OrderId} not found", id);
            return NotFound(new { message = $"Order {id} not found" });
        }

        _logger.LogInformation(
            "Order {OrderId} retrieved successfully - Amount: {Amount}",
            id,
            order.TotalAmount
        );
        return Ok(order);
    }

    [HttpPost]
    public async Task<ActionResult<Order>> Create([FromBody] CreateOrderRequest request)
    {
        _logger.LogInformation(
            "Creating order for customer {CustomerId}, items: {ItemCount}, amount: {Amount}",
            request.CustomerId,
            request.Items.Count,
            request.TotalAmount
        );

        try
        {
            var order = await _orderService.CreateOrderAsync(request);

            _logger.LogInformation(
                "Order {OrderId} created successfully for customer {CustomerId}",
                order.Id,
                request.CustomerId
            );

            return CreatedAtAction(
                nameof(GetById),
                new { id = order.Id },
                order
            );
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogError(
                ex,
                "Failed to create order for customer {CustomerId}: {ErrorMessage}",
                request.CustomerId,
                ex.Message
            );
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error creating order for customer {CustomerId}",
                request.CustomerId
            );
            return StatusCode(500, new { message = "Internal server error" });
        }
    }

    [HttpPut("{id}")]
    public ActionResult<Order> Update(string id, [FromBody] UpdateOrderRequest request)
    {
        _logger.LogInformation("Updating order {OrderId}", id);

        try
        {
            var order = _orderService.UpdateOrder(id, request);
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found for update", id);
                return NotFound();
            }

            _logger.LogInformation("Order {OrderId} updated successfully", id);
            return Ok(order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating order {OrderId}", id);
            return StatusCode(500, new { message = "Internal server error" });
        }
    }

    [HttpDelete("{id}")]
    public ActionResult Delete(string id)
    {
        _logger.LogInformation("Deleting order {OrderId}", id);

        var success = _orderService.DeleteOrder(id);
        if (!success)
        {
            _logger.LogWarning("Order {OrderId} not found for deletion", id);
            return NotFound();
        }

        _logger.LogInformation("Order {OrderId} deleted successfully", id);
        return NoContent();
    }

    [HttpPost("{id}/cancel")]
    public ActionResult CancelOrder(string id)
    {
        _logger.LogInformation("Cancelling order {OrderId}", id);

        try
        {
            var order = _orderService.CancelOrder(id);
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found for cancellation", id);
                return NotFound();
            }

            _logger.LogInformation("Order {OrderId} cancelled successfully", id);
            return Ok(order);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(
                "Cannot cancel order {OrderId}: {Reason}",
                id,
                ex.Message
            );
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpGet("simulate-error")]
    public ActionResult SimulateError()
    {
        _logger.LogWarning("Simulating error endpoint called");

        try
        {
            throw new Exception("Simulated error for testing");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Simulated error occurred");
            return StatusCode(500, new { message = "Simulated error" });
        }
    }
}