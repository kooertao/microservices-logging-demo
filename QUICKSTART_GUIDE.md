# Microservices Logging Demo - Quick Start Guide

This guide will get you up and running in 5 minutes!

## What You'll Get

- **2 Microservices**: OrderService and InventoryService
- **Full Logging Stack**: Elasticsearch + Fluent Bit + Kibana (EFK)
- **Distributed Tracing**: Correlation IDs across services
- **Structured Logging**: JSON logs with rich metadata

## Prerequisites

- Docker Desktop (with Kubernetes enabled) OR Minikube
- kubectl CLI tool
- PowerShell (Windows) or bash (Linux/Mac)

## Quick Start (5 minutes)

### 1. Deploy Everything

```powershell
# Windows (PowerShell)
.\deploy-all.ps1

# Linux/Mac (bash) - Coming soon, use kubectl commands below
```

This script will:
- Create Kubernetes namespaces
- Deploy Elasticsearch & Kibana
- Deploy Fluent Bit log collector
- Build Docker images
- Deploy OrderService & InventoryService

### 2. Access Kibana

```bash
# Port forward Kibana
kubectl port-forward svc/kibana -n logging 5601:5601
```

Open browser: http://localhost:5601

### 3. Configure Kibana

1. Navigate to **Management** ? **Stack Management** ? **Index Patterns**
2. Click **Create index pattern**
3. Enter pattern: `logs-microservices-*`
4. Click **Next step**
5. Select **@timestamp** as Time field
6. Click **Create index pattern**

### 4. Test the Services

```bash
# Port forward OrderService
kubectl port-forward svc/order-service -n microservices 8080:80
```

Open browser: http://localhost:8080/swagger

Or use the test script:
```powershell
.\test-logging.ps1 -OrderServiceUrl "http://localhost:8080"
```

### 5. View Logs in Kibana

1. Go to **Discover** in Kibana
2. Select `logs-microservices-*` index
3. You'll see logs from both services!

#### Try These Searches:

**Trace a single request:**
```
CorrelationId:"<paste-id-from-response-header>"
```

**View OrderService logs:**
```
k8s_labels.app:"order-service"
```

**View InventoryService logs:**
```
k8s_labels.app:"inventory-service"
```

**Find errors:**
```
Level:"Error"
```

**Slow requests (>500ms):**
```
Duration:>500
```

## Architecture Overview

```
???????????????????????????????????????????????????????????????
?                    Client (Browser/API)                     ?
???????????????????????????????????????????????????????????????
                           ? X-Correlation-ID: abc123
                           ?
                  ??????????????????
                  ?  OrderService  ? Logs: "Creating order..."
                  ??????????????????
                           ? X-Correlation-ID: abc123
                           ?
                  ??????????????????
                  ?InventoryService? Logs: "Checking inventory..."
                  ??????????????????
                           ?
            ???????????????????????????????
            ?         Fluent Bit          ? Collects logs
            ???????????????????????????????
                           ?
            ???????????????????????????????
            ?       Elasticsearch         ? Stores logs
            ???????????????????????????????
                           ?
            ???????????????????????????????
            ?          Kibana             ? Visualizes logs
            ???????????????????????????????
```

## Key Features Demonstrated

### 1. Correlation ID Propagation
- Single ID tracks request across multiple services
- Automatically propagated via HTTP headers
- Added to all log entries

### 2. Structured Logging
Every log includes:
- **Timestamp** (UTC)
- **Level** (Debug/Info/Warning/Error)
- **ServiceName** (OrderService/InventoryService)
- **CorrelationId**
- **Custom fields** (OrderId, ProductId, etc.)

### 3. Service Communication
- OrderService calls InventoryService via HTTP
- Both services log the interaction
- Same CorrelationId in both services' logs

### 4. Log Aggregation
- Fluent Bit collects logs from all pods
- Enriches with Kubernetes metadata
- Sends to Elasticsearch for searchability

## Common Commands

### View Pod Status
```bash
kubectl get pods -n microservices
kubectl get pods -n logging
```

### View Logs Directly
```bash
# OrderService logs
kubectl logs -n microservices -l app=order-service -f

# InventoryService logs
kubectl logs -n microservices -l app=inventory-service -f

# Fluent Bit logs
kubectl logs -n logging -l app=fluent-bit -f
```

### Restart Services
```bash
kubectl rollout restart deployment/order-service -n microservices
kubectl rollout restart deployment/inventory-service -n microservices
```

### Clean Up
```bash
kubectl delete namespace microservices
kubectl delete namespace logging
```

## Troubleshooting

### No logs appearing in Kibana?
1. Check Fluent Bit is running:
   ```bash
   kubectl get pods -n logging
   ```
2. Check Fluent Bit logs:
   ```bash
   kubectl logs -n logging -l app=fluent-bit
   ```
3. Verify Elasticsearch is accessible:
   ```bash
   kubectl port-forward -n logging svc/elasticsearch 9200:9200
   curl http://localhost:9200
   ```

### Services not starting?
1. Check pod status:
   ```bash
   kubectl describe pod <pod-name> -n microservices
   ```
2. Check events:
   ```bash
   kubectl get events -n microservices --sort-by='.lastTimestamp'
   ```

### Correlation ID not appearing?
- Check response headers: `X-Correlation-ID`
- Verify CorrelationIdMiddleware is registered
- Look in Kibana fields: Click "Available fields" ? Search "CorrelationId"

## Next Steps

1. **Read the Architecture Guide**: `LOGGING_ARCHITECTURE.md`
2. **Create Custom Visualizations** in Kibana
3. **Add Alerting**: Configure alerts for errors
4. **Add Metrics**: Integrate Prometheus
5. **Add Tracing**: Integrate OpenTelemetry

## Example: Create an Order

```bash
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -H "X-Correlation-ID: my-test-123" \
  -d '{
    "customerId": "CUST-123",
    "items": [
      {
        "productId": "PROD-1",
        "productName": "Laptop",
        "quantity": 1,
        "unitPrice": 1299.99
      }
    ],
    "totalAmount": 1299.99
  }'
```

Then search in Kibana:
```
CorrelationId:"my-test-123"
```

You'll see:
1. OrderService receives request
2. OrderService calls InventoryService
3. InventoryService checks inventory
4. InventoryService reserves inventory
5. OrderService creates order
6. Response returned

All traceable with ONE correlation ID! ??

## Questions?

Check out:
- `LOGGING_ARCHITECTURE.md` - Detailed architecture
- `test-logging.ps1` - Automated tests
- Kibana Discover - Your logs!

Happy logging! ??
