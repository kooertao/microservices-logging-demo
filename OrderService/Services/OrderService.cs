using OrderService.Models;

namespace OrderService.Services;

public interface IOrderBusinessService
{
    IEnumerable<Order> GetAllOrders();
    Order? GetOrderById(string id);
    Task<Order> CreateOrderAsync(CreateOrderRequest request);
    Order? UpdateOrder(string id, UpdateOrderRequest request);
    bool DeleteOrder(string id);
    Order? CancelOrder(string id);
}

public class OrderBusinessService : IOrderBusinessService
{
    private readonly List<Order> _orders = new();
    private readonly ILogger<OrderBusinessService> _logger;
    private readonly IInventoryServiceClient _inventoryClient;
    private readonly Random _random = new();

    public OrderBusinessService(
        ILogger<OrderBusinessService> logger,
        IInventoryServiceClient inventoryClient)
    {
        _logger = logger;
        _inventoryClient = inventoryClient;

        // 初始化一些示例数据
        _orders.Add(new Order
        {
            Id = "ORD-001",
            CustomerId = "CUST-100",
            Items = new List<OrderItem>
            {
                new() { ProductId = "PROD-1", ProductName = "Laptop", Quantity = 1, UnitPrice = 1299.99m }
            },
            TotalAmount = 1299.99m,
            Status = OrderStatus.Completed,
            CreatedAt = DateTime.UtcNow.AddDays(-2)
        });

        _logger.LogInformation("OrderBusinessService initialized with {Count} sample orders", _orders.Count);
    }

    public IEnumerable<Order> GetAllOrders()
    {
        _logger.LogDebug("Fetching all orders from in-memory store");
        return _orders.ToList();
    }

    public Order? GetOrderById(string id)
    {
        _logger.LogDebug("Searching for order {OrderId}", id);
        return _orders.FirstOrDefault(o => o.Id == id);
    }

    public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
    {
        var orderId = $"ORD-{_random.Next(1000, 9999)}";

        _logger.LogInformation(
            "Creating order {OrderId} - checking inventory for {ItemCount} items",
            orderId,
            request.Items.Count
        );

        // Check and reserve inventory for each item
        var reservations = new List<string>();
        try
        {
            foreach (var item in request.Items)
            {
                _logger.LogDebug(
                    "Checking inventory for order {OrderId}: Product={ProductId}, Quantity={Quantity}",
                    orderId,
                    item.ProductId,
                    item.Quantity
                );

                // Check inventory availability
                var checkResult = await _inventoryClient.CheckInventoryAsync(item.ProductId, item.Quantity);
                if (checkResult == null || !checkResult.Available)
                {
                    _logger.LogWarning(
                        "Insufficient inventory for order {OrderId}: Product={ProductId}, Requested={Requested}, Available={Available}",
                        orderId,
                        item.ProductId,
                        item.Quantity,
                        checkResult?.AvailableQuantity ?? 0
                    );
                    throw new InvalidOperationException($"Insufficient inventory for product {item.ProductId}");
                }

                // Reserve inventory
                var reserveResult = await _inventoryClient.ReserveInventoryAsync(
                    item.ProductId,
                    item.Quantity,
                    orderId
                );

                if (reserveResult == null || !reserveResult.Success)
                {
                    _logger.LogError(
                        "Failed to reserve inventory for order {OrderId}: Product={ProductId}",
                        orderId,
                        item.ProductId
                    );
                    throw new InvalidOperationException($"Failed to reserve inventory for product {item.ProductId}");
                }

                reservations.Add(reserveResult.ReservationId);
                _logger.LogInformation(
                    "Inventory reserved for order {OrderId}: Product={ProductId}, ReservationId={ReservationId}",
                    orderId,
                    item.ProductId,
                    reserveResult.ReservationId
                );
            }

            // All inventory checks passed, create the order
            var order = new Order
            {
                Id = orderId,
                CustomerId = request.CustomerId,
                Items = request.Items,
                TotalAmount = request.TotalAmount,
                Status = OrderStatus.Pending,
                CreatedAt = DateTime.UtcNow
            };

            _orders.Add(order);

            _logger.LogInformation(
                "Order {OrderId} created successfully with {ReservationCount} inventory reservations",
                order.Id,
                reservations.Count
            );

            // 模拟处理延迟
            await Task.Delay(_random.Next(50, 200));

            return order;
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Failed to create order {OrderId}, rolling back {ReservationCount} reservations",
                orderId,
                reservations.Count
            );

            // In a real system, you would release the reservations here
            throw;
        }
    }

    public Order? UpdateOrder(string id, UpdateOrderRequest request)
    {
        var order = _orders.FirstOrDefault(o => o.Id == id);
        if (order == null)
        {
            return null;
        }

        _logger.LogDebug(
            "Updating order {OrderId} status from {OldStatus} to {NewStatus}",
            id,
            order.Status,
            request.Status
        );

        order.Status = request.Status;
        order.UpdatedAt = DateTime.UtcNow;

        return order;
    }

    public bool DeleteOrder(string id)
    {
        var order = _orders.FirstOrDefault(o => o.Id == id);
        if (order == null)
        {
            return false;
        }

        _orders.Remove(order);
        _logger.LogInformation("Order {OrderId} removed from in-memory store", id);
        return true;
    }

    public Order? CancelOrder(string id)
    {
        var order = _orders.FirstOrDefault(o => o.Id == id);
        if (order == null)
        {
            return null;
        }

        if (order.Status == OrderStatus.Completed)
        {
            throw new InvalidOperationException("Cannot cancel completed order");
        }

        if (order.Status == OrderStatus.Cancelled)
        {
            throw new InvalidOperationException("Order is already cancelled");
        }

        order.Status = OrderStatus.Cancelled;
        order.UpdatedAt = DateTime.UtcNow;

        return order;
    }
}