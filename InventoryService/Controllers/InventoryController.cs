using Microsoft.AspNetCore.Mvc;
using InventoryService.Models;
using InventoryService.Services;

namespace InventoryService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InventoryController : ControllerBase
{
    private readonly ILogger<InventoryController> _logger;
    private readonly IInventoryBusinessService _inventoryService;

    public InventoryController(
        ILogger<InventoryController> logger,
        IInventoryBusinessService inventoryService)
    {
        _logger = logger;
        _inventoryService = inventoryService;
    }

    [HttpGet]
    public ActionResult<IEnumerable<InventoryItem>> GetAll()
    {
        _logger.LogInformation("Retrieving all inventory items");
        var items = _inventoryService.GetAllInventory();
        _logger.LogInformation("Retrieved {Count} inventory items", items.Count());
        return Ok(items);
    }

    [HttpGet("{productId}")]
    public ActionResult<InventoryItem> GetByProductId(string productId)
    {
        _logger.LogInformation("Retrieving inventory for product {ProductId}", productId);

        var item = _inventoryService.GetInventoryByProductId(productId);
        if (item == null)
        {
            _logger.LogWarning("Inventory not found for product {ProductId}", productId);
            return NotFound(new { message = $"Product {productId} not found" });
        }

        _logger.LogInformation(
            "Inventory retrieved for {ProductId}: Available={Available}, Reserved={Reserved}",
            productId,
            item.AvailableQuantity,
            item.ReservedQuantity
        );
        return Ok(item);
    }

    [HttpPost("check")]
    public ActionResult<CheckInventoryResponse> CheckInventory([FromBody] CheckInventoryRequest request)
    {
        _logger.LogInformation(
            "Checking inventory availability for product {ProductId}, quantity: {Quantity}",
            request.ProductId,
            request.Quantity
        );

        try
        {
            var response = _inventoryService.CheckInventory(request);

            _logger.LogInformation(
                "Inventory check completed for {ProductId}: Available={Available}",
                request.ProductId,
                response.Available
            );

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error checking inventory for product {ProductId}",
                request.ProductId
            );
            return StatusCode(500, new { message = "Internal server error" });
        }
    }

    [HttpPost("reserve")]
    public ActionResult<ReserveInventoryResponse> ReserveInventory([FromBody] ReserveInventoryRequest request)
    {
        _logger.LogInformation(
            "Reserving inventory for order {OrderId}, product {ProductId}, quantity: {Quantity}",
            request.OrderId,
            request.ProductId,
            request.Quantity
        );

        try
        {
            var response = _inventoryService.ReserveInventory(request);

            if (response.Success)
            {
                _logger.LogInformation(
                    "Inventory reserved successfully for order {OrderId}: ReservationId={ReservationId}",
                    request.OrderId,
                    response.ReservationId
                );
                return Ok(response);
            }
            else
            {
                _logger.LogWarning(
                    "Failed to reserve inventory for order {OrderId}: {Reason}",
                    request.OrderId,
                    response.Message
                );
                return BadRequest(response);
            }
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogError(
                ex,
                "System error reserving inventory for order {OrderId}",
                request.OrderId
            );
            return StatusCode(503, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error reserving inventory for order {OrderId}",
                request.OrderId
            );
            return StatusCode(500, new { message = "Internal server error" });
        }
    }

    [HttpPost("release")]
    public ActionResult ReleaseInventory([FromBody] CheckInventoryRequest request)
    {
        _logger.LogInformation(
            "Releasing inventory for product {ProductId}, quantity: {Quantity}",
            request.ProductId,
            request.Quantity
        );

        try
        {
            var success = _inventoryService.ReleaseInventory(request.ProductId, request.Quantity);
            if (!success)
            {
                _logger.LogWarning("Product {ProductId} not found for release", request.ProductId);
                return NotFound(new { message = "Product not found" });
            }

            _logger.LogInformation(
                "Inventory released successfully for product {ProductId}",
                request.ProductId
            );
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Error releasing inventory for product {ProductId}",
                request.ProductId
            );
            return StatusCode(500, new { message = "Internal server error" });
        }
    }
}
