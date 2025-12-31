# Microservices Logging Demo - Main Cleanup Script
# Remove all components while preserving logs

param(
    [switch]$Force
)

Write-Host "Cleaning up all components..." -ForegroundColor Yellow
Write-Host ""

# Get project root directory
$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptDir -Parent

if (-not $Force) {
    Write-Host "This will delete the following components:" -ForegroundColor Yellow
    Write-Host "  - Order Service" -ForegroundColor Yellow
    Write-Host "  - Inventory Service" -ForegroundColor Yellow
    Write-Host "  - Fluent Bit" -ForegroundColor Yellow
    Write-Host "  - Kibana" -ForegroundColor Yellow
    Write-Host "  - Elasticsearch" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "? Elasticsearch logs will be PRESERVED" -ForegroundColor Green
    Write-Host "   (PersistentVolumeClaims will NOT be deleted)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press Ctrl+C to cancel, or any other key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

# Remove microservices
Write-Host "[1/4] Removing microservices..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/OrderService/k8s/06-order-service.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/InventoryService/k8s/07-inventory-service.yaml" --ignore-not-found=true
Write-Host ""

# Remove Fluent Bit
Write-Host "[2/4] Removing Fluent Bit..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/05-fluent-bit-daemonset.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/k8s-infrastructure/04-fluent-bit-configmap.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/k8s-infrastructure/03-fluent-bit-rbac.yaml" --ignore-not-found=true
Write-Host ""

# Remove Kibana
Write-Host "[3/4] Removing Kibana..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/02-kibana.yaml" --ignore-not-found=true
Write-Host ""

# Remove Elasticsearch
Write-Host "[4/4] Removing Elasticsearch..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/01-elasticsearch.yaml" --ignore-not-found=true
Write-Host ""

# Wait for Pods to terminate
Write-Host "Waiting for pods to terminate..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
Write-Host ""

# Show status
Write-Host "Final Status:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Microservices namespace:" -ForegroundColor Cyan
kubectl get all -n microservices
Write-Host ""
Write-Host "Logging namespace:" -ForegroundColor Cyan
kubectl get all -n logging
Write-Host ""
Write-Host "Persistent Volume Claims (logs preserved):" -ForegroundColor Cyan
kubectl get pvc -n logging
Write-Host ""

Write-Host "Cleanup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Elasticsearch logs have been preserved in PersistentVolumeClaims" -ForegroundColor Green
Write-Host "   When you redeploy, Elasticsearch will reattach to the existing data" -ForegroundColor Gray
Write-Host ""

Write-Host "Additional cleanup options:" -ForegroundColor Cyan
Write-Host "  Delete PVCs (logs):   kubectl delete pvc -n logging -l app=elasticsearch" -ForegroundColor Gray
Write-Host "  Delete namespaces:    kubectl delete namespace logging microservices" -ForegroundColor Gray
Write-Host "  Remove Docker images: docker rmi order-service:latest inventory-service:latest" -ForegroundColor Gray
Write-Host ""
