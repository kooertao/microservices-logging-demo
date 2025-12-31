# Cleanup Infrastructure - Remove Elasticsearch, Kibana, Fluent Bit
# PowerShell ??

Write-Host "???  Cleaning up infrastructure components..." -ForegroundColor Yellow
Write-Host ""

# ???????
$ScriptDir = $PSScriptRoot
$ProjectRoot = Split-Path -Parent $ScriptDir
$InfraDir = Join-Path $ProjectRoot "k8s-infrastructure"

# ????????
if (-not (Test-Path $InfraDir)) {
    Write-Host "? Infrastructure directory not found: $InfraDir" -ForegroundColor Red
    exit 1
}

Write-Host "??  This will delete all infrastructure components (Elasticsearch, Kibana, Fluent Bit)" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to cancel, or any other key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host ""

# ?? Fluent Bit
Write-Host "[1/6] Removing Fluent Bit..." -ForegroundColor Yellow
kubectl delete -f "$InfraDir/05-fluent-bit-daemonset.yaml" --ignore-not-found=true
kubectl delete -f "$InfraDir/04-fluent-bit-configmap.yaml" --ignore-not-found=true
kubectl delete -f "$InfraDir/03-fluent-bit-rbac.yaml" --ignore-not-found=true
Write-Host ""

# ?? Kibana
Write-Host "[2/6] Removing Kibana..." -ForegroundColor Yellow
kubectl delete -f "$InfraDir/02-kibana.yaml" --ignore-not-found=true
Write-Host ""

# ?? Elasticsearch
Write-Host "[3/6] Removing Elasticsearch..." -ForegroundColor Yellow
kubectl delete -f "$InfraDir/01-elasticsearch.yaml" --ignore-not-found=true
Write-Host ""

# ?? Pods ??
Write-Host "[4/6] Waiting for pods to terminate..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
Write-Host ""

# ?? PVCs
Write-Host "[5/6] Removing PersistentVolumeClaims..." -ForegroundColor Yellow
kubectl delete pvc -n logging -l app=elasticsearch --ignore-not-found=true
Write-Host ""

# ??????
Write-Host "[6/6] Checking remaining resources in logging namespace..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Pods:" -ForegroundColor Cyan
kubectl get pods -n logging
Write-Host ""
Write-Host "Services:" -ForegroundColor Cyan
kubectl get svc -n logging
Write-Host ""
Write-Host "PVCs:" -ForegroundColor Cyan
kubectl get pvc -n logging
Write-Host ""

Write-Host "? Infrastructure cleanup completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Namespaces (logging, microservices) are kept." -ForegroundColor Yellow
Write-Host "To remove namespaces, run:" -ForegroundColor Yellow
Write-Host "  kubectl delete namespace logging" -ForegroundColor Gray
Write-Host "  kubectl delete namespace microservices" -ForegroundColor Gray
Write-Host ""
