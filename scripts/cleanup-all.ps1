# Cleanup All - Remove all microservices and infrastructure
# PowerShell ??

Write-Host "???  Cleaning up all components..." -ForegroundColor Yellow
Write-Host ""

# ???????
$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "??  This will delete ALL components:" -ForegroundColor Red
Write-Host "  - Order Service" -ForegroundColor Yellow
Write-Host "  - Inventory Service" -ForegroundColor Yellow
Write-Host "  - Fluent Bit" -ForegroundColor Yellow
Write-Host "  - Kibana" -ForegroundColor Yellow
Write-Host "  - Elasticsearch (including data)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to cancel, or any other key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

# ?????
Write-Host "[1/5] Removing microservices..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/OrderService/k8s/06-order-service.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/InventoryService/k8s/07-inventory-service.yaml" --ignore-not-found=true
Write-Host ""

# ?? Fluent Bit
Write-Host "[2/5] Removing Fluent Bit..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/05-fluent-bit-daemonset.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/k8s-infrastructure/04-fluent-bit-configmap.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/k8s-infrastructure/03-fluent-bit-rbac.yaml" --ignore-not-found=true
Write-Host ""

# ?? Kibana
Write-Host "[3/5] Removing Kibana..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/02-kibana.yaml" --ignore-not-found=true
Write-Host ""

# ?? Elasticsearch
Write-Host "[4/5] Removing Elasticsearch..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/01-elasticsearch.yaml" --ignore-not-found=true
Write-Host ""

# ?? Pods ??
Write-Host "? Waiting for pods to terminate..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
Write-Host ""

# ?? PVCs
Write-Host "[5/5] Removing PersistentVolumeClaims..." -ForegroundColor Yellow
kubectl delete pvc -n logging -l app=elasticsearch --ignore-not-found=true
Write-Host ""

# ????
Write-Host "?? Final Status:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Microservices namespace:" -ForegroundColor Cyan
kubectl get all -n microservices
Write-Host ""
Write-Host "Logging namespace:" -ForegroundColor Cyan
kubectl get all -n logging
Write-Host ""

Write-Host "? Cleanup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "To delete namespaces, run:" -ForegroundColor Yellow
Write-Host "  kubectl delete namespace logging microservices" -ForegroundColor Gray
Write-Host ""
Write-Host "To remove Docker images, run:" -ForegroundColor Yellow
Write-Host "  docker rmi order-service:latest inventory-service:latest" -ForegroundColor Gray
Write-Host ""
