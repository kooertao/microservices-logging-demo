# Microservices Logging Demo - Deployment Script
# This script deploys both OrderService and InventoryService with full EFK logging stack

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Microservices Logging Demo - Deployment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create Namespaces
Write-Host "[1/7] Creating Kubernetes namespaces..." -ForegroundColor Yellow
kubectl apply -f OrderService/k8s/00-namespace.yaml

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create namespaces" -ForegroundColor Red
    exit 1
}
Write-Host "? Namespaces created" -ForegroundColor Green
Write-Host ""

# Step 2: Deploy Elasticsearch
Write-Host "[2/7] Deploying Elasticsearch..." -ForegroundColor Yellow
kubectl apply -f OrderService/k8s/01-elasticsearch.yaml

Write-Host "Waiting for Elasticsearch to be ready (this may take a few minutes)..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

if ($LASTEXITCODE -ne 0) {
    Write-Host "Elasticsearch deployment failed or timeout" -ForegroundColor Red
    exit 1
}
Write-Host "? Elasticsearch ready" -ForegroundColor Green
Write-Host ""

# Step 3: Deploy Kibana
Write-Host "[3/7] Deploying Kibana..." -ForegroundColor Yellow
kubectl apply -f OrderService/k8s/02-kibana.yaml

Write-Host "Waiting for Kibana to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=180s

if ($LASTEXITCODE -ne 0) {
    Write-Host "Kibana deployment failed or timeout" -ForegroundColor Red
    exit 1
}
Write-Host "? Kibana ready" -ForegroundColor Green
Write-Host ""

# Step 4: Deploy Fluent Bit
Write-Host "[4/7] Deploying Fluent Bit..." -ForegroundColor Yellow
kubectl apply -f OrderService/k8s/03-fluent-bit-rbac.yaml
kubectl apply -f OrderService/k8s/04-fluent-bit-configmap.yaml
kubectl apply -f OrderService/k8s/05-fluent-bit-daemonset.yaml

Write-Host "Waiting for Fluent Bit pods to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
kubectl wait --for=condition=ready pod -l app=fluent-bit -n logging --timeout=60s

if ($LASTEXITCODE -ne 0) {
    Write-Host "Fluent Bit deployment failed or timeout" -ForegroundColor Red
    exit 1
}
Write-Host "? Fluent Bit ready" -ForegroundColor Green
Write-Host ""

# Step 5: Build Docker Images
Write-Host "[5/7] Building Docker images..." -ForegroundColor Yellow

Write-Host "Building OrderService..." -ForegroundColor Cyan
docker build -t order-service:latest -f OrderService/Dockerfile .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build OrderService image" -ForegroundColor Red
    exit 1
}

Write-Host "Building InventoryService..." -ForegroundColor Cyan
docker build -t inventory-service:latest -f InventoryService/Dockerfile .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build InventoryService image" -ForegroundColor Red
    exit 1
}

Write-Host "? Docker images built" -ForegroundColor Green
Write-Host ""

# Step 6: Deploy InventoryService
Write-Host "[6/7] Deploying InventoryService..." -ForegroundColor Yellow
kubectl apply -f InventoryService/k8s/07-inventory-service.yaml

Write-Host "Waiting for InventoryService to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
kubectl wait --for=condition=ready pod -l app=inventory-service -n microservices --timeout=120s

if ($LASTEXITCODE -ne 0) {
    Write-Host "InventoryService deployment failed or timeout" -ForegroundColor Red
    exit 1
}
Write-Host "? InventoryService ready" -ForegroundColor Green
Write-Host ""

# Step 7: Deploy OrderService
Write-Host "[7/7] Deploying OrderService..." -ForegroundColor Yellow
kubectl apply -f OrderService/k8s/06-order-service.yaml

Write-Host "Waiting for OrderService to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
kubectl wait --for=condition=ready pod -l app=order-service -n microservices --timeout=120s

if ($LASTEXITCODE -ne 0) {
    Write-Host "OrderService deployment failed or timeout" -ForegroundColor Red
    exit 1
}
Write-Host "? OrderService ready" -ForegroundColor Green
Write-Host ""

# Display Status
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Cluster Status:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Logging Stack (namespace: logging):" -ForegroundColor Cyan
kubectl get pods -n logging

Write-Host ""
Write-Host "Microservices (namespace: microservices):" -ForegroundColor Cyan
kubectl get pods -n microservices

Write-Host ""
Write-Host "Services:" -ForegroundColor Cyan
kubectl get svc -n logging
kubectl get svc -n microservices

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Access URLs" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan

# Get service URLs
$kibanaPort = kubectl get svc kibana -n logging -o jsonpath='{.spec.ports[0].nodePort}'
$orderPort = kubectl get svc order-service -n microservices -o jsonpath='{.spec.ports[0].nodePort}'

if ($kibanaPort) {
    Write-Host "Kibana UI: http://localhost:$kibanaPort" -ForegroundColor Green
} else {
    Write-Host "Kibana: Use 'kubectl port-forward svc/kibana -n logging 5601:5601'" -ForegroundColor Yellow
}

if ($orderPort) {
    Write-Host "OrderService API: http://localhost:$orderPort/swagger" -ForegroundColor Green
} else {
    Write-Host "OrderService: Use 'kubectl port-forward svc/order-service -n microservices 8080:80'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Access Kibana and create index pattern: logs-microservices-*" -ForegroundColor White
Write-Host "2. Test OrderService by creating an order (it will call InventoryService)" -ForegroundColor White
Write-Host "3. Search logs in Kibana using CorrelationId to trace requests" -ForegroundColor White
Write-Host ""
Write-Host "Example: Create an order" -ForegroundColor Cyan
Write-Host @"
curl -X POST http://localhost:$orderPort/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "CUST-123",
    "items": [
      {"productId": "PROD-1", "productName": "Laptop", "quantity": 1, "unitPrice": 1299.99}
    ],
    "totalAmount": 1299.99
  }'
"@ -ForegroundColor Gray

Write-Host ""
Write-Host "For detailed architecture information, see: LOGGING_ARCHITECTURE.md" -ForegroundColor Yellow
Write-Host ""
