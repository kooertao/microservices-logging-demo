# Microservices Logging Solution - Implementation Summary

## Overview
This solution demonstrates comprehensive logging for a microservices architecture where **OrderService** calls **InventoryService**, with all logs centralized and traceable using correlation IDs.

## Solution Architecture

### Services Created
1. **OrderService** (existing, enhanced)
   - Manages customer orders
   - Calls InventoryService to check/reserve inventory
   - Propagates correlation IDs to downstream services

2. **InventoryService** (NEW)
   - Manages product inventory
   - Provides check and reserve endpoints
   - Receives correlation IDs from upstream services

### Logging Stack (EFK)
- **Elasticsearch**: Centralized log storage
- **Fluent Bit**: Lightweight log collector (DaemonSet)
- **Kibana**: Log visualization and search UI

## Key Features Implemented

### 1. Correlation ID Propagation
? **Problem Solved**: Tracking requests across multiple services

**Implementation**:
- `CorrelationIdMiddleware`: Generates/receives correlation ID
  - Adds to response headers
  - Adds to logging scope (all logs include it)
  
- `CorrelationIdDelegatingHandler`: Propagates to outbound HTTP calls
  - Automatically adds `X-Correlation-ID` header
  - Logs outbound call details

**Flow**:
```
Client Request
    ? (generates ID: abc-123)
OrderService (logs with abc-123)
    ? (passes ID via header)
InventoryService (logs with abc-123)
    ?
All logs searchable by: CorrelationId:"abc-123"
```

### 2. Structured JSON Logging
? **Problem Solved**: Consistent, parseable log format

**Configuration**:
```csharp
builder.Logging.AddJsonConsole(options =>
{
    options.IncludeScopes = true;  // Include correlation ID
    options.TimestampFormat = "yyyy-MM-dd HH:mm:ss.fff ";
    options.UseUtcTimestamp = true;
    options.JsonWriterOptions = new JsonWriterOptions
    {
        Indented = false  // Single line for Fluent Bit
    };
});
```

**Log Structure**:
```json
{
  "Timestamp": "2024-01-15 10:30:45.123",
  "Level": "Information",
  "ServiceName": "OrderService",
  "CorrelationId": "abc-123",
  "Message": "Order ORD-1234 created",
  "OrderId": "ORD-1234",
  "Duration": 250
}
```

### 3. Service-to-Service Communication
? **Problem Solved**: Reliable communication with logging

**Implementation**:
- `InventoryServiceClient`: Typed HttpClient for InventoryService
  - Logs all outbound calls
  - Measures duration
  - Handles errors with context

**Registration**:
```csharp
builder.Services.AddHttpClient<IInventoryServiceClient, InventoryServiceClient>(client =>
{
    client.BaseAddress = new Uri("http://inventory-service...");
    client.Timeout = TimeSpan.FromSeconds(30);
})
.AddHttpMessageHandler<CorrelationIdDelegatingHandler>();
```

### 4. Log Collection Pipeline
? **Problem Solved**: Centralized log aggregation

**Fluent Bit Configuration**:
- **Input**: Tail all container logs
- **Filters**: 
  - Kubernetes metadata (pod, namespace, labels)
  - Custom cluster name
- **Output**: 
  - Elasticsearch (with compression)
  - Stdout (for debugging)

**Index Pattern**: `logs-microservices-YYYY.MM.DD`

## Files Created/Modified

### New Files
```
InventoryService/
??? InventoryService.csproj
??? Program.cs
??? Dockerfile
??? appsettings.json
??? appsettings.Development.json
??? Controllers/
?   ??? InventoryController.cs
??? Models/
?   ??? InventoryItem.cs
??? Services/
?   ??? InventoryBusinessService.cs
??? Middleware/
?   ??? CorrelationIdMiddleware.cs
??? k8s/
    ??? 07-inventory-service.yaml

OrderService/Services/
??? CorrelationIdDelegatingHandler.cs
??? InventoryServiceClient.cs

Documentation/
??? LOGGING_ARCHITECTURE.md
??? QUICKSTART_GUIDE.md
??? deploy-all.ps1
??? test-logging.ps1
```

### Modified Files
```
OrderService/
??? Program.cs (added HttpClient configuration)
??? Services/OrderService.cs (added InventoryService calls)
??? Controllers/OrderController.cs (made Create async)
??? Middleware/CorrelationIdMiddleware.cs (added ServiceName)
??? appsettings.json (added InventoryService URL)
??? appsettings.Development.json (added local URL)
```

## Logging Patterns Implemented

### 1. Request Logging (Middleware)
```csharp
_logger.LogInformation(
    "Request started: {Method} {Path}",
    context.Request.Method,
    context.Request.Path
);
```

### 2. Business Operation Logging
```csharp
_logger.LogInformation(
    "Order {OrderId} created successfully with {ReservationCount} inventory reservations",
    order.Id,
    reservations.Count
);
```

### 3. External Service Call Logging
```csharp
_logger.LogInformation(
    "Calling InventoryService: Order={OrderId}, Product={ProductId}, Quantity={Quantity}",
    orderId,
    productId,
    quantity
);

// After call
_logger.LogInformation(
    "InventoryService completed: Success={Success}, Duration={Duration}ms",
    result?.Success,
    sw.ElapsedMilliseconds
);
```

### 4. Error Logging with Context
```csharp
catch (HttpRequestException ex)
{
    _logger.LogError(
        ex,
        "HTTP error calling InventoryService for order {OrderId}, Duration={Duration}ms",
        orderId,
        sw.ElapsedMilliseconds
    );
    throw new InvalidOperationException("Inventory service unavailable", ex);
}
```

## Deployment

### Quick Deploy
```powershell
.\deploy-all.ps1
```

### Manual Deploy
```bash
# 1. Namespaces
kubectl apply -f OrderService/k8s/00-namespace.yaml

# 2. Logging Stack
kubectl apply -f OrderService/k8s/01-elasticsearch.yaml
kubectl apply -f OrderService/k8s/02-kibana.yaml
kubectl apply -f OrderService/k8s/03-fluent-bit-rbac.yaml
kubectl apply -f OrderService/k8s/04-fluent-bit-configmap.yaml
kubectl apply -f OrderService/k8s/05-fluent-bit-daemonset.yaml

# 3. Build Images
docker build -t order-service:latest -f OrderService/Dockerfile .
docker build -t inventory-service:latest -f InventoryService/Dockerfile .

# 4. Deploy Services
kubectl apply -f InventoryService/k8s/07-inventory-service.yaml
kubectl apply -f OrderService/k8s/06-order-service.yaml
```

## Testing

### Manual Test
```bash
# Port forward
kubectl port-forward svc/order-service -n microservices 8080:80

# Create order
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: test-123" \
  -d '{
    "customerId": "CUST-123",
    "items": [{"productId": "PROD-1", "productName": "Laptop", "quantity": 1, "unitPrice": 1299.99}],
    "totalAmount": 1299.99
  }'
```

### Automated Test
```powershell
.\test-logging.ps1 -OrderServiceUrl "http://localhost:8080"
```

## Kibana Usage

### Create Index Pattern
1. Navigate to **Management** ? **Stack Management**
2. Click **Index Patterns** ? **Create index pattern**
3. Pattern: `logs-microservices-*`
4. Time field: `@timestamp`

### Search Examples

**Trace a request**:
```
CorrelationId:"abc-123"
```

**View specific service**:
```
k8s_labels.app:"order-service"
```

**Find errors**:
```
Level:"Error"
```

**Slow requests**:
```
Duration:>1000
```

**Cross-service trace**:
```
CorrelationId:"abc-123" AND (k8s_labels.app:"order-service" OR k8s_labels.app:"inventory-service")
```

## Benefits Achieved

### 1. Distributed Tracing
? Single correlation ID tracks requests across all services
? Complete request flow visible in Kibana
? Easy debugging of multi-service transactions

### 2. Centralized Logging
? All logs in one place (Elasticsearch)
? Powerful search and filtering (Kibana)
? No need to SSH into pods

### 3. Structured Data
? Consistent log format (JSON)
? Rich metadata (service, pod, namespace)
? Easy parsing and analysis

### 4. Operational Insights
? Request duration tracking
? Error rate monitoring
? Service dependency visualization
? Performance bottleneck identification

## Best Practices Followed

### Logging
- ? Structured logging (JSON)
- ? Semantic log levels
- ? Rich contextual data
- ? No sensitive data logged
- ? Performance metrics included

### Microservices
- ? Correlation ID propagation
- ? Timeout configuration
- ? Retry logic ready
- ? Health checks
- ? Graceful error handling

### Kubernetes
- ? Separate namespaces (logging, microservices)
- ? Resource limits defined
- ? Health probes configured
- ? Labels for organization
- ? DaemonSet for log collection

## Next Steps (Optional Enhancements)

1. **Metrics**: Add Prometheus + Grafana
2. **Tracing**: Add OpenTelemetry/Jaeger
3. **Alerting**: Configure Kibana/Elasticsearch alerts
4. **APM**: Add Elastic APM for deeper insights
5. **Log Retention**: Configure ILM policies
6. **Security**: Add authentication to services
7. **Resilience**: Add Polly for retry/circuit breaker

## Documentation

- **Architecture Guide**: `LOGGING_ARCHITECTURE.md`
- **Quick Start**: `QUICKSTART_GUIDE.md`
- **Deployment Script**: `deploy-all.ps1`
- **Test Script**: `test-logging.ps1`

## Summary

This solution provides a **production-ready logging infrastructure** for microservices:

1. ? **Two services** communicating with full traceability
2. ? **Correlation IDs** flowing through the entire request chain
3. ? **Structured JSON logs** with rich metadata
4. ? **Centralized collection** via Fluent Bit
5. ? **Elasticsearch storage** with powerful search
6. ? **Kibana visualization** for analysis
7. ? **Complete documentation** and deployment scripts

**Key Achievement**: Track a single user request through multiple microservices using ONE correlation ID! ??
