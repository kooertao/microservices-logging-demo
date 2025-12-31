# Deploy Infrastructure Only - Elasticsearch, Kibana, Fluent Bit
# PowerShell ??

Write-Host "?? Deploying infrastructure components..." -ForegroundColor Cyan
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

# ?? 1: ??????
Write-Host "[1/7] Creating namespaces..." -ForegroundColor Green
kubectl apply -f "$InfraDir/00-namespace.yaml"
Write-Host ""

# ?? 2: ?? Elasticsearch
Write-Host "[2/7] Deploying Elasticsearch..." -ForegroundColor Green
kubectl apply -f "$InfraDir/01-elasticsearch.yaml"
Write-Host ""

# ?? 3: ?? Elasticsearch ??
Write-Host "[3/7] Waiting for Elasticsearch to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s
Write-Host "? Elasticsearch is ready" -ForegroundColor Green
Write-Host ""

# ?? 4: ?? Kibana
Write-Host "[4/7] Deploying Kibana..." -ForegroundColor Green
kubectl apply -f "$InfraDir/02-kibana.yaml"
Write-Host ""

# ?? 5: ?? Kibana ??
Write-Host "[5/7] Waiting for Kibana to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=180s
Write-Host "? Kibana is ready" -ForegroundColor Green
Write-Host ""

# ?? 6: ?? Fluent Bit
Write-Host "[6/7] Deploying Fluent Bit..." -ForegroundColor Green
kubectl apply -f "$InfraDir/03-fluent-bit-rbac.yaml"
kubectl apply -f "$InfraDir/04-fluent-bit-configmap.yaml"
kubectl apply -f "$InfraDir/05-fluent-bit-daemonset.yaml"
Write-Host ""

# ?? 7: ?? Fluent Bit ??
Write-Host "[7/7] Waiting for Fluent Bit to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=fluent-bit -n logging --timeout=180s
Write-Host "? Fluent Bit is ready" -ForegroundColor Green
Write-Host ""

# ??????
Write-Host "?? Infrastructure Status:" -ForegroundColor Cyan
Write-Host ""
kubectl get pods -n logging
Write-Host ""

Write-Host "?? Services:" -ForegroundColor Cyan
Write-Host ""
kubectl get svc -n logging
Write-Host ""

Write-Host "? Infrastructure deployment completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs (after port-forwarding):" -ForegroundColor Cyan
Write-Host "  Kibana:         http://localhost:5601"
Write-Host "  Elasticsearch:  http://localhost:9200"
Write-Host ""
Write-Host "Port-forward commands:" -ForegroundColor Yellow
Write-Host "  kubectl port-forward -n logging svc/kibana 5601:5601"
Write-Host "  kubectl port-forward -n logging svc/elasticsearch 9200:9200"
Write-Host ""
