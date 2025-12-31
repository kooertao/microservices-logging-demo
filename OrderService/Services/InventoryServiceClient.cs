using System.Text.Json.Serialization;

namespace OrderService.Services;

public interface IInventoryServiceClient
{
    Task<CheckInventoryResponse?> CheckInventoryAsync(string productId, int quantity);
    Task<ReserveInventoryResponse?> ReserveInventoryAsync(string productId, int quantity, string orderId);
}

public class InventoryServiceClient : IInventoryServiceClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<InventoryServiceClient> _logger;

    public InventoryServiceClient(HttpClient httpClient, ILogger<InventoryServiceClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<CheckInventoryResponse?> CheckInventoryAsync(string productId, int quantity)
    {
        _logger.LogInformation(
            "Calling InventoryService to check inventory for product {ProductId}, quantity: {Quantity}",
            productId,
            quantity
        );

        var sw = System.Diagnostics.Stopwatch.StartNew();

        try
        {
            var request = new CheckInventoryRequest
            {
                ProductId = productId,
                Quantity = quantity
            };

            var response = await _httpClient.PostAsJsonAsync("/api/inventory/check", request);
            sw.Stop();

            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<CheckInventoryResponse>();
                
                _logger.LogInformation(
                    "InventoryService check completed: Product={ProductId}, Available={Available}, Duration={Duration}ms",
                    productId,
                    result?.Available,
                    sw.ElapsedMilliseconds
                );

                return result;
            }

            _logger.LogWarning(
                "InventoryService check failed: Product={ProductId}, StatusCode={StatusCode}, Duration={Duration}ms",
                productId,
                response.StatusCode,
                sw.ElapsedMilliseconds
            );

            return null;
        }
        catch (HttpRequestException ex)
        {
            sw.Stop();
            _logger.LogError(
                ex,
                "HTTP error calling InventoryService for product {ProductId}, Duration={Duration}ms",
                productId,
                sw.ElapsedMilliseconds
            );
            throw new InvalidOperationException("Inventory service unavailable", ex);
        }
        catch (Exception ex)
        {
            sw.Stop();
            _logger.LogError(
                ex,
                "Unexpected error calling InventoryService for product {ProductId}, Duration={Duration}ms",
                productId,
                sw.ElapsedMilliseconds
            );
            throw;
        }
    }

    public async Task<ReserveInventoryResponse?> ReserveInventoryAsync(string productId, int quantity, string orderId)
    {
        _logger.LogInformation(
            "Calling InventoryService to reserve inventory: Order={OrderId}, Product={ProductId}, Quantity={Quantity}",
            orderId,
            productId,
            quantity
        );

        var sw = System.Diagnostics.Stopwatch.StartNew();

        try
        {
            var request = new ReserveInventoryRequest
            {
                ProductId = productId,
                Quantity = quantity,
                OrderId = orderId
            };

            var response = await _httpClient.PostAsJsonAsync("/api/inventory/reserve", request);
            sw.Stop();

            if (response.IsSuccessStatusCode)
            {
                var result = await response.Content.ReadFromJsonAsync<ReserveInventoryResponse>();
                
                _logger.LogInformation(
                    "InventoryService reservation completed: Order={OrderId}, Success={Success}, ReservationId={ReservationId}, Duration={Duration}ms",
                    orderId,
                    result?.Success,
                    result?.ReservationId,
                    sw.ElapsedMilliseconds
                );

                return result;
            }

            var errorContent = await response.Content.ReadAsStringAsync();
            _logger.LogWarning(
                "InventoryService reservation failed: Order={OrderId}, StatusCode={StatusCode}, Error={Error}, Duration={Duration}ms",
                orderId,
                response.StatusCode,
                errorContent,
                sw.ElapsedMilliseconds
            );

            return null;
        }
        catch (HttpRequestException ex)
        {
            sw.Stop();
            _logger.LogError(
                ex,
                "HTTP error calling InventoryService for order {OrderId}, Duration={Duration}ms",
                orderId,
                sw.ElapsedMilliseconds
            );
            throw new InvalidOperationException("Inventory service unavailable", ex);
        }
        catch (Exception ex)
        {
            sw.Stop();
            _logger.LogError(
                ex,
                "Unexpected error calling InventoryService for order {OrderId}, Duration={Duration}ms",
                orderId,
                sw.ElapsedMilliseconds
            );
            throw;
        }
    }
}

// DTOs for communication with InventoryService
public class CheckInventoryRequest
{
    [JsonPropertyName("productId")]
    public string ProductId { get; set; } = string.Empty;
    
    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }
}

public class CheckInventoryResponse
{
    [JsonPropertyName("productId")]
    public string ProductId { get; set; } = string.Empty;
    
    [JsonPropertyName("available")]
    public bool Available { get; set; }
    
    [JsonPropertyName("availableQuantity")]
    public int AvailableQuantity { get; set; }
    
    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;
}

public class ReserveInventoryRequest
{
    [JsonPropertyName("productId")]
    public string ProductId { get; set; } = string.Empty;
    
    [JsonPropertyName("quantity")]
    public int Quantity { get; set; }
    
    [JsonPropertyName("orderId")]
    public string OrderId { get; set; } = string.Empty;
}

public class ReserveInventoryResponse
{
    [JsonPropertyName("success")]
    public bool Success { get; set; }
    
    [JsonPropertyName("message")]
    public string Message { get; set; } = string.Empty;
    
    [JsonPropertyName("reservationId")]
    public string ReservationId { get; set; } = string.Empty;
}
