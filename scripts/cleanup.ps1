# Microservices Logging Demo - Main Cleanup Script
# Remove all components with optional data archiving

param(
    [switch]$ArchiveData,
    [string]$ArchiveDir = ".\es-archives",
    [switch]$Force
)

Write-Host "???  Cleaning up all components..." -ForegroundColor Yellow
Write-Host ""

# Get project root directory
$ScriptDir = $PSScriptRoot
$ProjectRoot = $ScriptDir

# Archive data if requested
if ($ArchiveData) {
    Write-Host "?? Archiving Elasticsearch data before cleanup..." -ForegroundColor Cyan
    Write-Host ""
    
    $archiveScript = Join-Path $ScriptDir "scripts\utils\archive-es-data.ps1"
    
    if (Test-Path $archiveScript) {
        & $archiveScript -OutputDir $ArchiveDir
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "? Archive failed. Cleanup aborted." -ForegroundColor Red
            exit 1
        }
        
        Write-Host ""
        Write-Host "? Archive completed. Proceeding with cleanup..." -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "??  Archive script not found: $archiveScript" -ForegroundColor Yellow
        Write-Host "Continuing without archive..." -ForegroundColor Yellow
        Write-Host ""
    }
}

if (-not $Force) {
    Write-Host "??  This will delete ALL components:" -ForegroundColor Red
    Write-Host "  - Order Service" -ForegroundColor Yellow
    Write-Host "  - Inventory Service" -ForegroundColor Yellow
    Write-Host "  - Fluent Bit" -ForegroundColor Yellow
    Write-Host "  - Kibana" -ForegroundColor Yellow
    Write-Host "  - Elasticsearch (including all data)" -ForegroundColor Red
    Write-Host ""
    if ($ArchiveData) {
        Write-Host "? Data has been archived to: $ArchiveDir" -ForegroundColor Green
        Write-Host ""
    }
    Write-Host "Press Ctrl+C to cancel, or any other key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

# Remove microservices
Write-Host "[1/5] Removing microservices..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/OrderService/k8s/06-order-service.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/InventoryService/k8s/07-inventory-service.yaml" --ignore-not-found=true
Write-Host ""

# Remove Fluent Bit
Write-Host "[2/5] Removing Fluent Bit..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/05-fluent-bit-daemonset.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/k8s-infrastructure/04-fluent-bit-configmap.yaml" --ignore-not-found=true
kubectl delete -f "$ProjectRoot/k8s-infrastructure/03-fluent-bit-rbac.yaml" --ignore-not-found=true
Write-Host ""

# Remove Kibana
Write-Host "[3/5] Removing Kibana..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/02-kibana.yaml" --ignore-not-found=true
Write-Host ""

# Remove Elasticsearch
Write-Host "[4/5] Removing Elasticsearch..." -ForegroundColor Yellow
kubectl delete -f "$ProjectRoot/k8s-infrastructure/01-elasticsearch.yaml" --ignore-not-found=true
Write-Host ""

# Wait for Pods to terminate
Write-Host "? Waiting for pods to terminate..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
Write-Host ""

# Remove PVCs
Write-Host "[5/5] Removing PersistentVolumeClaims..." -ForegroundColor Yellow
kubectl delete pvc -n logging -l app=elasticsearch --ignore-not-found=true
Write-Host ""

# Show status
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

if ($ArchiveData) {
    Write-Host "?? Your data has been archived to: $ArchiveDir" -ForegroundColor Cyan
    Write-Host "To restore, run: .\scripts\utils\restore-es-data.ps1 -ArchiveDir <archive-directory>" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "?? Additional cleanup options:" -ForegroundColor Cyan
Write-Host "  Delete namespaces:    kubectl delete namespace logging microservices" -ForegroundColor Gray
Write-Host "  Remove Docker images: docker rmi order-service:latest inventory-service:latest" -ForegroundColor Gray
Write-Host ""
