namespace InventoryService.Models;

public class InventoryItem
{
    public string ProductId { get; set; } = string.Empty;
    public string ProductName { get; set; } = string.Empty;
    public int AvailableQuantity { get; set; }
    public int ReservedQuantity { get; set; }
    public decimal UnitPrice { get; set; }
    public DateTime LastUpdated { get; set; }
}

public class CheckInventoryRequest
{
    public string ProductId { get; set; } = string.Empty;
    public int Quantity { get; set; }
}

public class CheckInventoryResponse
{
    public string ProductId { get; set; } = string.Empty;
    public bool Available { get; set; }
    public int AvailableQuantity { get; set; }
    public string Message { get; set; } = string.Empty;
}

public class ReserveInventoryRequest
{
    public string ProductId { get; set; } = string.Empty;
    public int Quantity { get; set; }
    public string OrderId { get; set; } = string.Empty;
}

public class ReserveInventoryResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public string ReservationId { get; set; } = string.Empty;
}
