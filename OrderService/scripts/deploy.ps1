# Microservices Logging Demo - 部署脚本
# PowerShell 版本

Write-Host "🚀 Starting deployment of Microservices Logging Demo..." -ForegroundColor Cyan
Write-Host ""

# 获取项目根目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

# 步骤 1: 创建命名空间
Write-Host "[1/8] Creating namespaces..." -ForegroundColor Green
kubectl apply -f k8s/00-namespace.yaml

# 步骤 2: 部署 Elasticsearch
Write-Host "[2/8] Deploying Elasticsearch..." -ForegroundColor Green
kubectl apply -f k8s/01-elasticsearch.yaml

Write-Host "⏳ Waiting for Elasticsearch to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

# 步骤 3: 部署 Kibana
Write-Host "[3/8] Deploying Kibana..." -ForegroundColor Green
kubectl apply -f k8s/02-kibana.yaml

Write-Host "⏳ Waiting for Kibana to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=180s

# 步骤 4: 部署 Fluent Bit
Write-Host "[4/8] Deploying Fluent Bit..." -ForegroundColor Green
kubectl apply -f k8s/03-fluent-bit-rbac.yaml
kubectl apply -f k8s/04-fluent-bit-configmap.yaml
kubectl apply -f k8s/05-fluent-bit-daemonset.yaml

Write-Host "⏳ Waiting for Fluent Bit to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=fluent-bit -n logging --timeout=180s

# 步骤 5: 构建 Docker 镜像
Write-Host "[5/8] Building Docker images..." -ForegroundColor Green
$ParentDir = Split-Path -Parent $ProjectRoot
Set-Location $ParentDir
docker build -t order-service:latest -f OrderService/Dockerfile .
Set-Location $ProjectRoot

# 步骤 6: 部署微服务
Write-Host "[6/8] Deploying microservices..." -ForegroundColor Green
kubectl apply -f k8s/06-order-service.yaml

Write-Host "⏳ Waiting for microservices to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=order-service -n microservices --timeout=180s

# 步骤 7: 获取访问信息
Write-Host ""
Write-Host "[7/8] Getting access information..." -ForegroundColor Green
Write-Host ""

Write-Host "📊 Kibana:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:5601 (after port-forward)"
Write-Host "  Command: kubectl port-forward -n logging svc/kibana 5601:5601"
Write-Host ""

Write-Host "🔧 Order Service:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:8080 (after port-forward)"
Write-Host "  Command: kubectl port-forward -n microservices svc/order-service 8080:80"
Write-Host "  Swagger: http://localhost:8080/swagger"
Write-Host "  Note: Service port 80 -> Container port 8080"
Write-Host ""

Write-Host "🔍 Elasticsearch:" -ForegroundColor Cyan
Write-Host "  URL: http://localhost:9200 (after port-forward)"
Write-Host "  Command: kubectl port-forward -n logging svc/elasticsearch 9200:9200"
Write-Host ""

# 步骤 8: 显示有用的命令
Write-Host "[8/8] Useful commands:" -ForegroundColor Green
Write-Host ""
Write-Host "  # 查看日志"
Write-Host "  kubectl logs -n microservices -l app=order-service -f"
Write-Host "  kubectl logs -n logging -l app=fluent-bit -f"
Write-Host ""
Write-Host "  # 查看 Pods"
Write-Host "  kubectl get pods -n microservices"
Write-Host "  kubectl get pods -n logging"
Write-Host ""
Write-Host "  # 查看完整状态"
Write-Host "  .\scripts\status.ps1"
Write-Host ""
Write-Host "  # 查询 Elasticsearch"
Write-Host "  Invoke-WebRequest -Uri http://localhost:9200/_cat/indices?v"
Write-Host ""

Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run: kubectl port-forward -n logging svc/kibana 5601:5601"
Write-Host "  2. Run: kubectl port-forward -n microservices svc/order-service 8080:80"
Write-Host "  3. Open: http://localhost:5601"
Write-Host "  4. Generate test logs by accessing: http://localhost:8080/swagger"
