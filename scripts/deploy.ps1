# Microservices Logging Demo - Main Deployment Script
# Deploys infrastructure and all microservices

Write-Host "?? Starting deployment of Microservices Logging Demo..." -ForegroundColor Cyan
Write-Host ""

# Get project root directory
$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path -Parent $ScriptDir

# Step 1: Deploy infrastructure (Elasticsearch, Kibana, Fluent Bit)
Write-Host "[1/6] Deploying infrastructure components..." -ForegroundColor Green
Write-Host "  - Namespaces"
kubectl apply -f "$ProjectRoot/k8s-infrastructure/00-namespace.yaml"

Write-Host "  - Elasticsearch"
kubectl apply -f "$ProjectRoot/k8s-infrastructure/01-elasticsearch.yaml"

Write-Host "? Waiting for Elasticsearch to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

Write-Host "  - Kibana"
kubectl apply -f "$ProjectRoot/k8s-infrastructure/02-kibana.yaml"

Write-Host "? Waiting for Kibana to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=180s

Write-Host "  - Fluent Bit"
kubectl apply -f "$ProjectRoot/k8s-infrastructure/03-fluent-bit-rbac.yaml"
kubectl apply -f "$ProjectRoot/k8s-infrastructure/04-fluent-bit-configmap.yaml"
kubectl apply -f "$ProjectRoot/k8s-infrastructure/05-fluent-bit-daemonset.yaml"

Write-Host "? Waiting for Fluent Bit to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=fluent-bit -n logging --timeout=180s

# Step 2: Build Order Service Docker image
Write-Host ""
Write-Host "[2/6] Building Order Service Docker image..." -ForegroundColor Green
Set-Location $ProjectRoot
docker build -t order-service:latest -f OrderService/Dockerfile .

# Step 3: Deploy Order Service
Write-Host ""
Write-Host "[3/6] Deploying Order Service..." -ForegroundColor Green
kubectl apply -f "$ProjectRoot/OrderService/k8s/06-order-service.yaml"

Write-Host "? Waiting for Order Service to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=order-service -n microservices --timeout=180s

# Step 4: Build Inventory Service Docker image
Write-Host ""
Write-Host "[4/6] Building Inventory Service Docker image..." -ForegroundColor Green
docker build -t inventory-service:latest -f InventoryService/Dockerfile .

# Step 5: Deploy Inventory Service
Write-Host ""
Write-Host "[5/6] Deploying Inventory Service..." -ForegroundColor Green
kubectl apply -f "$ProjectRoot/InventoryService/k8s/07-inventory-service.yaml"

Write-Host "? Waiting for Inventory Service to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=inventory-service -n microservices --timeout=180s

# Step 6: Display access information
Write-Host ""
Write-Host "[6/6] Getting access information..." -ForegroundColor Green
Write-Host ""

Write-Host "?? Kibana:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:5601"
Write-Host "  Command: kubectl port-forward -n logging svc/kibana 5601:5601"
Write-Host ""

Write-Host "?? Order Service:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:8080"
Write-Host "  Command: kubectl port-forward -n microservices svc/order-service 8080:80"
Write-Host "  Swagger: http://localhost:8080/swagger"
Write-Host ""

Write-Host "?? Inventory Service:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:8081"
Write-Host "  Command: kubectl port-forward -n microservices svc/inventory-service 8081:80"
Write-Host ""

Write-Host "?? Elasticsearch:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:9200"
Write-Host "  Command: kubectl port-forward -n logging svc/elasticsearch 9200:9200"
Write-Host ""

Write-Host "? Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "?? Useful commands:" -ForegroundColor Cyan
Write-Host "  View logs:  kubectl logs -n microservices -l app=order-service -f"
Write-Host "  View pods:  kubectl get pods -n microservices"
Write-Host "  Query ES:   curl http://localhost:9200/_cat/indices?v"
Write-Host ""
Write-Host "?? Advanced features:" -ForegroundColor Cyan
Write-Host "  Archive ES data:  .\scripts\utils\archive-es-data.ps1"
Write-Host "  Manage archives:  .\scripts\utils\manage-es-archives.ps1"
Write-Host "  Interactive demo: .\scripts\utils\archive-demo.ps1"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: kubectl port-forward -n logging svc/kibana 5601:5601"
Write-Host "  2. Run: kubectl port-forward -n microservices svc/order-service 8080:80"
Write-Host "  3. Open: http://localhost:5601 (Kibana)"
Write-Host "  4. Generate logs: http://localhost:8080/swagger"
