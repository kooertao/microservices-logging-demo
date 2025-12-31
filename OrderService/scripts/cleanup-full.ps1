# Microservices Logging Demo - ??????
# PowerShell ??
# ???????????????? Elasticsearch ??

Write-Host "?? Full Cleanup - Microservices Logging Demo" -ForegroundColor Yellow
Write-Host "??  WARNING: This will DELETE ALL DATA including logs!" -ForegroundColor Red
Write-Host ""

# ????
$confirmation = Read-Host "Are you sure you want to delete ALL data? Type 'yes' to confirm"
if ($confirmation -ne "yes") {
    Write-Host "? Cleanup cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "???  Starting full cleanup..." -ForegroundColor Red
Write-Host ""

# ?????
Write-Host "[1/4] Deleting microservices..." -ForegroundColor Yellow
kubectl delete -f k8s/06-order-service.yaml --ignore-not-found=true

# ??????
Write-Host "[2/4] Deleting logging components..." -ForegroundColor Yellow
kubectl delete -f k8s/05-fluent-bit-daemonset.yaml --ignore-not-found=true
kubectl delete -f k8s/04-fluent-bit-configmap.yaml --ignore-not-found=true
kubectl delete -f k8s/03-fluent-bit-rbac.yaml --ignore-not-found=true
kubectl delete -f k8s/02-kibana.yaml --ignore-not-found=true
kubectl delete -f k8s/01-elasticsearch.yaml --ignore-not-found=true

# ??????
Write-Host "? Waiting for resources to be deleted..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# ??????????? PVC?
Write-Host "[3/4] Deleting namespaces (including PVCs)..." -ForegroundColor Yellow
kubectl delete namespace microservices --ignore-not-found=true
kubectl delete namespace logging --ignore-not-found=true

# ??????????
Write-Host "? Waiting for namespaces to be deleted..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# ???????? PersistentVolumes
Write-Host "[4/4] Checking for orphaned PersistentVolumes..." -ForegroundColor Yellow
$orphanedPVs = kubectl get pv -o jsonpath='{.items[?(@.status.phase=="Released")].metadata.name}' 2>$null

if ($orphanedPVs) {
    Write-Host "   Found orphaned PVs, deleting..." -ForegroundColor Yellow
    foreach ($pv in $orphanedPVs.Split()) {
        if ($pv) {
            Write-Host "   Deleting PV: $pv" -ForegroundColor Yellow
            kubectl delete pv $pv --ignore-not-found=true
        }
    }
} else {
    Write-Host "   No orphaned PVs found" -ForegroundColor Green
}

Write-Host ""
Write-Host "? Full cleanup completed! All data has been removed." -ForegroundColor Green
Write-Host ""
Write-Host "To redeploy the demo:" -ForegroundColor White
Write-Host "  .\scripts\deploy.ps1" -ForegroundColor Cyan
