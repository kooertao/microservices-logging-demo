using InventoryService.Models;

namespace InventoryService.Services;

public interface IInventoryBusinessService
{
    IEnumerable<InventoryItem> GetAllInventory();
    InventoryItem? GetInventoryByProductId(string productId);
    CheckInventoryResponse CheckInventory(CheckInventoryRequest request);
    ReserveInventoryResponse ReserveInventory(ReserveInventoryRequest request);
    bool ReleaseInventory(string productId, int quantity);
}

public class InventoryBusinessService : IInventoryBusinessService
{
    private readonly List<InventoryItem> _inventory = new();
    private readonly ILogger<InventoryBusinessService> _logger;
    private readonly Random _random = new();

    public InventoryBusinessService(ILogger<InventoryBusinessService> logger)
    {
        _logger = logger;

        // ???????????
        _inventory.AddRange(new[]
        {
            new InventoryItem
            {
                ProductId = "PROD-1",
                ProductName = "Laptop",
                AvailableQuantity = 50,
                ReservedQuantity = 0,
                UnitPrice = 1299.99m,
                LastUpdated = DateTime.UtcNow
            },
            new InventoryItem
            {
                ProductId = "PROD-2",
                ProductName = "Mouse",
                AvailableQuantity = 200,
                ReservedQuantity = 0,
                UnitPrice = 29.99m,
                LastUpdated = DateTime.UtcNow
            },
            new InventoryItem
            {
                ProductId = "PROD-3",
                ProductName = "Keyboard",
                AvailableQuantity = 100,
                ReservedQuantity = 0,
                UnitPrice = 79.99m,
                LastUpdated = DateTime.UtcNow
            },
            new InventoryItem
            {
                ProductId = "PROD-4",
                ProductName = "Monitor",
                AvailableQuantity = 5,
                ReservedQuantity = 0,
                UnitPrice = 399.99m,
                LastUpdated = DateTime.UtcNow
            }
        });

        _logger.LogInformation("InventoryBusinessService initialized with {Count} products", _inventory.Count);
    }

    public IEnumerable<InventoryItem> GetAllInventory()
    {
        _logger.LogDebug("Fetching all inventory items from in-memory store");
        return _inventory.ToList();
    }

    public InventoryItem? GetInventoryByProductId(string productId)
    {
        _logger.LogDebug("Searching for inventory item {ProductId}", productId);
        return _inventory.FirstOrDefault(i => i.ProductId == productId);
    }

    public CheckInventoryResponse CheckInventory(CheckInventoryRequest request)
    {
        _logger.LogInformation(
            "Checking inventory for product {ProductId}, requested quantity: {Quantity}",
            request.ProductId,
            request.Quantity
        );

        var item = _inventory.FirstOrDefault(i => i.ProductId == request.ProductId);
        if (item == null)
        {
            _logger.LogWarning("Product {ProductId} not found in inventory", request.ProductId);
            return new CheckInventoryResponse
            {
                ProductId = request.ProductId,
                Available = false,
                AvailableQuantity = 0,
                Message = "Product not found"
            };
        }

        // ???????
        Thread.Sleep(_random.Next(10, 50));

        var available = item.AvailableQuantity >= request.Quantity;
        
        _logger.LogInformation(
            "Inventory check result for {ProductId}: Available={Available}, Requested={Requested}, InStock={InStock}",
            request.ProductId,
            available,
            request.Quantity,
            item.AvailableQuantity
        );

        return new CheckInventoryResponse
        {
            ProductId = request.ProductId,
            Available = available,
            AvailableQuantity = item.AvailableQuantity,
            Message = available ? "Sufficient inventory" : "Insufficient inventory"
        };
    }

    public ReserveInventoryResponse ReserveInventory(ReserveInventoryRequest request)
    {
        _logger.LogInformation(
            "Reserving inventory for order {OrderId}, product {ProductId}, quantity: {Quantity}",
            request.OrderId,
            request.ProductId,
            request.Quantity
        );

        var item = _inventory.FirstOrDefault(i => i.ProductId == request.ProductId);
        if (item == null)
        {
            _logger.LogWarning("Product {ProductId} not found for reservation", request.ProductId);
            return new ReserveInventoryResponse
            {
                Success = false,
                Message = "Product not found"
            };
        }

        // ?? 5% ??????????
        if (_random.Next(100) < 5)
        {
            _logger.LogError(
                "Simulated system error during inventory reservation for order {OrderId}",
                request.OrderId
            );
            throw new InvalidOperationException("Inventory system temporarily unavailable");
        }

        if (item.AvailableQuantity < request.Quantity)
        {
            _logger.LogWarning(
                "Insufficient inventory for product {ProductId}: Available={Available}, Requested={Requested}",
                request.ProductId,
                item.AvailableQuantity,
                request.Quantity
            );
            return new ReserveInventoryResponse
            {
                Success = false,
                Message = "Insufficient inventory"
            };
        }

        // ????
        item.AvailableQuantity -= request.Quantity;
        item.ReservedQuantity += request.Quantity;
        item.LastUpdated = DateTime.UtcNow;

        var reservationId = $"RES-{Guid.NewGuid():N}";

        _logger.LogInformation(
            "Inventory reserved successfully: ReservationId={ReservationId}, Order={OrderId}, Product={ProductId}, Quantity={Quantity}, RemainingStock={Remaining}",
            reservationId,
            request.OrderId,
            request.ProductId,
            request.Quantity,
            item.AvailableQuantity
        );

        // ??????
        Thread.Sleep(_random.Next(20, 100));

        return new ReserveInventoryResponse
        {
            Success = true,
            Message = "Inventory reserved successfully",
            ReservationId = reservationId
        };
    }

    public bool ReleaseInventory(string productId, int quantity)
    {
        _logger.LogInformation(
            "Releasing inventory for product {ProductId}, quantity: {Quantity}",
            productId,
            quantity
        );

        var item = _inventory.FirstOrDefault(i => i.ProductId == productId);
        if (item == null)
        {
            _logger.LogWarning("Product {ProductId} not found for release", productId);
            return false;
        }

        item.AvailableQuantity += quantity;
        item.ReservedQuantity = Math.Max(0, item.ReservedQuantity - quantity);
        item.LastUpdated = DateTime.UtcNow;

        _logger.LogInformation(
            "Inventory released: Product={ProductId}, Quantity={Quantity}, NewAvailable={Available}",
            productId,
            quantity,
            item.AvailableQuantity
        );

        return true;
    }
}
