# Microservices Logging Demo - Clean scripts
# PowerShell 版本
# 注意：此脚本会保留 Elasticsearch 数据（日志不会丢失）

Write-Host "🧹 Cleaning up Microservices Logging Demo..." -ForegroundColor Yellow
Write-Host "📦 Elasticsearch data will be preserved" -ForegroundColor Green
Write-Host ""

# 删除微服务
Write-Host "[1/4] Deleting microservices..." -ForegroundColor Yellow
kubectl delete -f ..\k8s\06-order-service.yaml --ignore-not-found=true

# 删除日志组件（但保留 Elasticsearch 的 StatefulSet 来保护 PVC）
Write-Host "[2/4] Deleting logging components..." -ForegroundColor Yellow
kubectl delete -f ..\k8s\05-fluent-bit-daemonset.yaml --ignore-not-found=true
kubectl delete -f ..\k8s\04-fluent-bit-configmap.yaml --ignore-not-found=true
kubectl delete -f ..\k8s\03-fluent-bit-rbac.yaml --ignore-not-found=true
kubectl delete -f ..\k8s\02-kibana.yaml --ignore-not-found=true

# 删除 Elasticsearch StatefulSet 但保留 PVC
Write-Host "   Deleting Elasticsearch StatefulSet (preserving data)..." -ForegroundColor Yellow
kubectl delete statefulset elasticsearch -n logging --ignore-not-found=true
kubectl delete service elasticsearch -n logging --ignore-not-found=true

# 等待资源删除
Write-Host "⏳ Waiting for resources to be deleted..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 删除微服务命名空间
Write-Host "[3/4] Deleting microservices namespace..." -ForegroundColor Yellow
kubectl delete namespace microservices --ignore-not-found=true

# 检查并显示保留的 PVC
Write-Host "[4/4] Checking preserved data..." -ForegroundColor Yellow
$pvcs = kubectl get pvc -n logging -o jsonpath='{.items[*].metadata.name}' 2>$null
if ($pvcs) {
    Write-Host "   ✅ Preserved PVCs in 'logging' namespace:" -ForegroundColor Green
    kubectl get pvc -n logging
} else {
    Write-Host "   ⚠️  No PVCs found in 'logging' namespace" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Cleanup completed! Elasticsearch data preserved." -ForegroundColor Green
Write-Host ""
Write-Host "📊 Your logs are safe in the persistent volume." -ForegroundColor Cyan
Write-Host ""
Write-Host "To restore services with existing data:" -ForegroundColor White
Write-Host "  .\scripts\deploy.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "To view preserved resources:" -ForegroundColor White
Write-Host "  kubectl get pvc -n logging" -ForegroundColor Cyan
Write-Host "  kubectl get pv" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  To completely remove data (including logs):" -ForegroundColor Yellow
Write-Host "  kubectl delete namespace logging" -ForegroundColor Red
Write-Host "  kubectl delete pv --all" -ForegroundColor Red
