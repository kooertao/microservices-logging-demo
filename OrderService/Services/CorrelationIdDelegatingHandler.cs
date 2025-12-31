namespace OrderService.Services;

public class CorrelationIdDelegatingHandler : DelegatingHandler
{
    private const string CorrelationIdHeader = "X-Correlation-ID";
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<CorrelationIdDelegatingHandler> _logger;

    public CorrelationIdDelegatingHandler(
        IHttpContextAccessor httpContextAccessor,
        ILogger<CorrelationIdDelegatingHandler> logger)
    {
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        // ??? HTTP ????? Correlation ID
        var correlationId = _httpContextAccessor.HttpContext?.Request.Headers[CorrelationIdHeader].FirstOrDefault();
        
        if (!string.IsNullOrEmpty(correlationId) && !request.Headers.Contains(CorrelationIdHeader))
        {
            request.Headers.Add(CorrelationIdHeader, correlationId);
            
            _logger.LogDebug(
                "Adding Correlation ID {CorrelationId} to outgoing request to {RequestUri}",
                correlationId,
                request.RequestUri
            );
        }

        return await base.SendAsync(request, cancellationToken);
    }
}
