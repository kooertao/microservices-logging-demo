namespace InventoryService.Middleware;

public class CorrelationIdMiddleware
{
    private const string CorrelationIdHeader = "X-Correlation-ID";
    private readonly RequestDelegate _next;
    private readonly ILogger<CorrelationIdMiddleware> _logger;

    public CorrelationIdMiddleware(RequestDelegate next, ILogger<CorrelationIdMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Retrieve Correlation ID
        var correlationId = context.Request.Headers[CorrelationIdHeader].FirstOrDefault()
            ?? Guid.NewGuid().ToString();

        // Add Correlation ID to Response Headers
        context.Response.Headers.TryAdd(CorrelationIdHeader, correlationId);

        // Create a logging scope
        using (_logger.BeginScope(new Dictionary<string, object>
        {
            ["CorrelationId"] = correlationId,
            ["RequestPath"] = context.Request.Path.ToString(),
            ["RequestMethod"] = context.Request.Method,
            ["ClientIP"] = context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            ["ServiceName"] = "InventoryService"
        }))
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();

            _logger.LogInformation(
                "Request started: {Method} {Path}",
                context.Request.Method,
                context.Request.Path
            );

            try
            {
                await _next(context);
                sw.Stop();

                _logger.LogInformation(
                    "Request completed: {Method} {Path} - Status: {StatusCode}, Duration: {Duration}ms",
                    context.Request.Method,
                    context.Request.Path,
                    context.Response.StatusCode,
                    sw.ElapsedMilliseconds
                );
            }
            catch (Exception ex)
            {
                sw.Stop();

                _logger.LogError(
                    ex,
                    "Request failed: {Method} {Path} - Duration: {Duration}ms",
                    context.Request.Method,
                    context.Request.Path,
                    sw.ElapsedMilliseconds
                );

                throw;
            }
        }
    }
}
