# Microservices Logging Demo - Architecture Guide

## Overview

This demo showcases a comprehensive logging solution for microservices running on Kubernetes using the **EFK Stack** (Elasticsearch, Fluent Bit, Kibana) with **distributed tracing** through correlation IDs.

## Architecture Components

### Services
1. **OrderService** - Manages customer orders
2. **InventoryService** - Manages product inventory
3. **Service Communication** - OrderService calls InventoryService via HTTP

### Logging Stack
1. **Elasticsearch** - Centralized log storage and search
2. **Fluent Bit** - Lightweight log collector (DaemonSet on each node)
3. **Kibana** - Log visualization and analysis UI

## Logging Strategy

### 1. Structured Logging (JSON)
Both services output **JSON-formatted logs** to stdout:
- **Timestamp** (UTC)
- **Log Level** (Debug, Information, Warning, Error)
- **Message**
- **Structured Properties** (OrderId, ProductId, etc.)
- **Scopes** (CorrelationId, ServiceName, etc.)

Example log:
```json
{
  "Timestamp": "2024-01-15 10:30:45.123",
  "Level": "Information",
  "Category": "OrderService.Controllers.OrdersController",
  "Message": "Order ORD-1234 created successfully",
  "Scopes": {
    "CorrelationId": "abc123-def456",
    "ServiceName": "OrderService",
    "RequestPath": "/api/orders",
    "RequestMethod": "POST"
  },
  "State": {
    "OrderId": "ORD-1234",
    "CustomerId": "CUST-100"
  }
}
```

### 2. Correlation ID Propagation
**Critical for distributed tracing across microservices:**

#### Flow:
1. **Client Request** ? OrderService
   - If no `X-Correlation-ID` header exists, generate new GUID
   - Add to logging scope
   - Return in response header

2. **OrderService** ? InventoryService
   - `CorrelationIdDelegatingHandler` automatically adds header
   - Same CorrelationId flows through entire request chain

3. **InventoryService Processing**
   - Receives `X-Correlation-ID` from OrderService
   - Uses same ID in all logs

#### Benefits:
- **Trace complete flow** of a single request across multiple services
- **Debug distributed transactions** easily
- **Measure end-to-end latency**

### 3. Log Collection Pipeline

```
???????????????????      ????????????????????      ???????????????????
?  OrderService   ????????   Fluent Bit     ???????? Elasticsearch   ?
?  (JSON logs)    ?      ?  (DaemonSet)     ?      ?  (Storage)      ?
???????????????????      ????????????????????      ???????????????????
                                ?                            ?
???????????????????             ?                            ?
? InventoryService???????????????                            ?
?  (JSON logs)    ?                                          ?
???????????????????                                          ?
                                                    ???????????????????
                                                    ?     Kibana      ?
                                                    ? (Visualization) ?
                                                    ???????????????????
```

**Fluent Bit Configuration:**
- **Input**: Tail all container logs (`/var/log/containers/*.log`)
- **Filters**:
  - Kubernetes metadata enrichment (pod, namespace, labels)
  - Custom cluster name
- **Output**: 
  - Elasticsearch (with compression)
  - Stdout (for debugging)

### 4. Key Logging Patterns

#### A. Request/Response Logging
```csharp
// In CorrelationIdMiddleware
_logger.LogInformation(
    "Request started: {Method} {Path}",
    context.Request.Method,
    context.Request.Path
);

// After processing
_logger.LogInformation(
    "Request completed: {Method} {Path} - Status: {StatusCode}, Duration: {Duration}ms",
    context.Request.Method,
    context.Request.Path,
    context.Response.StatusCode,
    sw.ElapsedMilliseconds
);
```

#### B. Business Operation Logging
```csharp
_logger.LogInformation(
    "Order {OrderId} created successfully with {ReservationCount} inventory reservations",
    order.Id,
    reservations.Count
);
```

#### C. External Service Call Logging
```csharp
_logger.LogInformation(
    "Calling InventoryService to check inventory for product {ProductId}, quantity: {Quantity}",
    productId,
    quantity
);

// After call
_logger.LogInformation(
    "InventoryService check completed: Product={ProductId}, Available={Available}, Duration={Duration}ms",
    productId,
    result?.Available,
    sw.ElapsedMilliseconds
);
```

#### D. Error Logging
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

## Deployment Guide

### Prerequisites
- Kubernetes cluster (Minikube, Kind, or cloud provider)
- kubectl configured
- Docker for building images

### Step 1: Create Namespaces
```bash
kubectl apply -f OrderService/k8s/00-namespace.yaml
```

### Step 2: Deploy Logging Stack
```bash
# Elasticsearch
kubectl apply -f OrderService/k8s/01-elasticsearch.yaml

# Kibana
kubectl apply -f OrderService/k8s/02-kibana.yaml

# Fluent Bit (RBAC, ConfigMap, DaemonSet)
kubectl apply -f OrderService/k8s/03-fluent-bit-rbac.yaml
kubectl apply -f OrderService/k8s/04-fluent-bit-configmap.yaml
kubectl apply -f OrderService/k8s/05-fluent-bit-daemonset.yaml
```

### Step 3: Build Service Images
```bash
# OrderService
docker build -t order-service:latest -f OrderService/Dockerfile .

# InventoryService
docker build -t inventory-service:latest -f InventoryService/Dockerfile .
```

### Step 4: Deploy Services
```bash
# OrderService
kubectl apply -f OrderService/k8s/06-order-service.yaml

# InventoryService
kubectl apply -f InventoryService/k8s/07-inventory-service.yaml
```

### Step 5: Access Services
```bash
# Get OrderService URL
kubectl get svc order-service -n microservices

# Get Kibana URL
kubectl get svc kibana -n logging
```

## Using Kibana for Log Analysis

### 1. Create Index Pattern
- Navigate to **Management** ? **Stack Management** ? **Index Patterns**
- Create pattern: `logs-microservices-*`
- Set time field: `@timestamp`

### 2. Discover Logs
- Go to **Discover**
- Select `logs-microservices-*` index

### 3. Search Examples

#### Find all logs for a specific order:
```
k8s_labels.app:"order-service" AND OrderId:"ORD-1234"
```

#### Trace a request using CorrelationId:
```
CorrelationId:"abc123-def456"
```

#### Find errors in InventoryService:
```
k8s_labels.app:"inventory-service" AND Level:"Error"
```

#### Slow requests (>1000ms):
```
Duration:>1000
```

### 4. Create Visualizations
- **Bar Chart**: Error count by service
- **Line Chart**: Request duration over time
- **Pie Chart**: Log level distribution
- **Data Table**: Top error messages

## Best Practices

### 1. Structured Logging
? **DO**:
```csharp
_logger.LogInformation("Order {OrderId} created for customer {CustomerId}", orderId, customerId);
```

? **DON'T**:
```csharp
_logger.LogInformation($"Order {orderId} created for customer {customerId}");
```

### 2. Log Levels
- **Debug**: Detailed debugging info (disabled in production)
- **Information**: General flow (requests, business operations)
- **Warning**: Unexpected but recoverable (retry, fallback)
- **Error**: Failures requiring attention

### 3. Performance
- Use **scopes** for contextual data (automatically added to all logs)
- Avoid logging in tight loops
- Consider sampling for high-volume operations

### 4. Security
- **Never log**: Passwords, tokens, credit cards, PII
- **Sanitize**: User input before logging
- **Be careful with**: Customer IDs, order details

## Monitoring & Alerting

### Key Metrics to Track
1. **Request Rate**: Requests per second per service
2. **Error Rate**: Percentage of failed requests
3. **Response Time**: p50, p95, p99 latencies
4. **Service Availability**: Health check failures

### Alert Examples
- Error rate > 5% for 5 minutes
- p95 latency > 1000ms
- Service unavailable for 2 minutes
- Elasticsearch disk usage > 80%

## Troubleshooting

### No logs in Kibana?
```bash
# Check Fluent Bit pods
kubectl get pods -n logging
kubectl logs -n logging fluent-bit-xxxxx

# Check Elasticsearch
kubectl logs -n logging elasticsearch-0
```

### Correlation ID not propagating?
- Verify `CorrelationIdDelegatingHandler` is registered
- Check HTTP client configuration
- Look for `X-Correlation-ID` header in logs

### High log volume?
- Adjust log levels in `appsettings.json`
- Configure Fluent Bit filters to exclude noisy logs
- Implement sampling for high-frequency operations

## Extending the Architecture

### Adding New Services
1. Copy logging configuration from existing service
2. Add `CorrelationIdMiddleware`
3. Use `CorrelationIdDelegatingHandler` for outbound calls
4. Create K8s deployment with logging labels
5. Fluent Bit automatically collects logs

### Adding Metrics (Prometheus)
- Install Prometheus & Grafana
- Use `prometheus-net` NuGet package
- Export custom metrics (request count, duration, etc.)

### Adding Tracing (Jaeger/Zipkin)
- Install OpenTelemetry SDK
- Configure exporters
- Automatic span creation for HTTP calls

## Resources
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [ASP.NET Core Logging](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging/)
