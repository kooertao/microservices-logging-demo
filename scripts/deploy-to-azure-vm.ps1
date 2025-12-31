# Azure VM ???????
# ????????? Azure ???????

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$VmName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$VmSize = "Standard_D4s_v3",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "azureuser"
)

$ErrorActionPreference = "Stop"

Write-Host "?? Starting Azure VM deployment..." -ForegroundColor Cyan
Write-Host ""

# ???????????
function Test-CommandExists {
    param($command)
    $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}

# ?? Azure CLI
if (-not (Test-CommandExists "az")) {
    Write-Host "? Azure CLI not found. Please install it first." -ForegroundColor Red
    Write-Host "   Download from: https://docs.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# ?? Docker
if (-not (Test-CommandExists "docker")) {
    Write-Host "? Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

Write-Host "[1/10] Checking Azure login status..." -ForegroundColor Green
$loginStatus = az account show 2>$null
if (-not $loginStatus) {
    Write-Host "??  Not logged in to Azure. Logging in..." -ForegroundColor Yellow
    az login
}

$subscription = az account show --query name -o tsv
Write-Host "? Logged in to subscription: $subscription" -ForegroundColor Green
Write-Host ""

# ?????
Write-Host "[2/10] Creating resource group: $ResourceGroup..." -ForegroundColor Green
az group create --name $ResourceGroup --location $Location --output none
Write-Host "? Resource group created" -ForegroundColor Green
Write-Host ""

# ??????
Write-Host "[3/10] Creating virtual network..." -ForegroundColor Green
az network vnet create `
    --resource-group $ResourceGroup `
    --name "${VmName}-vnet" `
    --address-prefix 10.0.0.0/16 `
    --subnet-name default `
    --subnet-prefix 10.0.1.0/24 `
    --output none
Write-Host "? Virtual network created" -ForegroundColor Green
Write-Host ""

# ???????
Write-Host "[4/10] Creating network security group with rules..." -ForegroundColor Green
az network nsg create `
    --resource-group $ResourceGroup `
    --name "${VmName}-nsg" `
    --output none

# ??????
$rules = @(
    @{Name="allow-ssh"; Priority=100; Port=22},
    @{Name="allow-http"; Priority=110; Port=80},
    @{Name="allow-https"; Priority=120; Port=443},
    @{Name="allow-kibana"; Priority=130; Port=5601},
    @{Name="allow-order-service"; Priority=140; Port=8080}
)

foreach ($rule in $rules) {
    az network nsg rule create `
        --resource-group $ResourceGroup `
        --nsg-name "${VmName}-nsg" `
        --name $rule.Name `
        --priority $rule.Priority `
        --source-address-prefixes '*' `
        --destination-port-ranges $rule.Port `
        --access Allow `
        --protocol Tcp `
        --output none
}
Write-Host "? Network security group created with rules" -ForegroundColor Green
Write-Host ""

# ???? IP
Write-Host "[5/10] Creating public IP address..." -ForegroundColor Green
az network public-ip create `
    --resource-group $ResourceGroup `
    --name "${VmName}-ip" `
    --sku Standard `
    --allocation-method Static `
    --output none
Write-Host "? Public IP created" -ForegroundColor Green
Write-Host ""

# ?????
Write-Host "[6/10] Creating virtual machine (this may take a few minutes)..." -ForegroundColor Green
az vm create `
    --resource-group $ResourceGroup `
    --name $VmName `
    --image Ubuntu2204 `
    --size $VmSize `
    --admin-username $AdminUsername `
    --generate-ssh-keys `
    --public-ip-address "${VmName}-ip" `
    --nsg "${VmName}-nsg" `
    --vnet-name "${VmName}-vnet" `
    --subnet default `
    --os-disk-size-gb 128 `
    --storage-sku Premium_LRS `
    --output none

Write-Host "? Virtual machine created" -ForegroundColor Green
Write-Host ""

# ???? IP
Write-Host "[7/10] Getting VM public IP address..." -ForegroundColor Green
$publicIp = az vm show `
    --resource-group $ResourceGroup `
    --name $VmName `
    --show-details `
    --query publicIps `
    --output tsv

Write-Host "? VM Public IP: $publicIp" -ForegroundColor Green
Write-Host ""

# ?? Docker ??
Write-Host "[8/10] Building Docker image..." -ForegroundColor Green
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$parentDir = Split-Path -Parent $projectRoot

Set-Location $parentDir
docker build -t order-service:latest -f OrderService/Dockerfile . --quiet
Set-Location $projectRoot

Write-Host "? Docker image built" -ForegroundColor Green
Write-Host ""

# ????
Write-Host "[9/10] Saving and transferring Docker image to VM..." -ForegroundColor Green
docker save order-service:latest -o order-service.tar

# ?? VM ????
Write-Host "? Waiting for VM to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# ????? VM
Write-Host "? Transferring image to VM (this may take a few minutes)..." -ForegroundColor Yellow
scp -o StrictHostKeyChecking=no order-service.tar "${AdminUsername}@${publicIp}:~/"

# ?? k8s ??
Write-Host "? Transferring Kubernetes configurations..." -ForegroundColor Yellow
scp -o StrictHostKeyChecking=no -r "$projectRoot/OrderService/k8s" "${AdminUsername}@${publicIp}:~/"

# ????????
Remove-Item order-service.tar -Force

Write-Host "? Files transferred to VM" -ForegroundColor Green
Write-Host ""

# ? VM ????????
Write-Host "[10/10] Installing dependencies and deploying application on VM..." -ForegroundColor Green

$setupScript = @'
#!/bin/bash
set -e

echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

echo "Loading Docker image..."
docker load -i ~/order-service.tar

echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "Waiting for k3s to be ready..."
sleep 30

echo "Deploying applications..."
cd ~/k8s

kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-elasticsearch.yaml
echo "Waiting for Elasticsearch..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

kubectl apply -f 02-kibana.yaml
echo "Waiting for Kibana..."
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=180s

kubectl apply -f 03-fluent-bit-rbac.yaml
kubectl apply -f 04-fluent-bit-configmap.yaml
kubectl apply -f 05-fluent-bit-daemonset.yaml
echo "Waiting for Fluent Bit..."
kubectl wait --for=condition=ready pod -l app=fluent-bit -n logging --timeout=180s

kubectl apply -f 06-order-service.yaml
echo "Waiting for Order Service..."
kubectl wait --for=condition=ready pod -l app=order-service -n microservices --timeout=180s

echo "Configuring NodePort services..."
kubectl patch svc kibana -n logging -p '{"spec":{"type":"NodePort","ports":[{"port":5601,"nodePort":30561}]}}'
kubectl patch svc order-service -n microservices -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30080}]}}'

echo "Installing and configuring Nginx..."
sudo apt-get update
sudo apt-get install nginx -y

sudo tee /etc/nginx/sites-available/microservices << 'NGINX_EOF'
server {
    listen 5601;
    server_name _;
    location / {
        proxy_pass http://localhost:30561;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 8080;
    server_name _;
    location / {
        proxy_pass http://localhost:30080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX_EOF

sudo ln -sf /etc/nginx/sites-available/microservices /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "? Deployment completed successfully!"
'@

# ?????????
$setupScript | Out-File -FilePath "setup.sh" -Encoding ASCII -NoNewline

# ?????????
scp -o StrictHostKeyChecking=no setup.sh "${AdminUsername}@${publicIp}:~/"
ssh -o StrictHostKeyChecking=no "${AdminUsername}@${publicIp}" "chmod +x ~/setup.sh && ~/setup.sh"

# ??????
Remove-Item setup.sh -Force

Write-Host "? Installation and deployment completed!" -ForegroundColor Green
Write-Host ""

# ??????
Write-Host "???????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host "?? Deployment Successful!" -ForegroundColor Green
Write-Host "???????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "?? Access Information:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ???  VM Public IP: $publicIp" -ForegroundColor White
Write-Host ""
Write-Host "  ?? Kibana (Logs Dashboard):" -ForegroundColor Cyan
Write-Host "     http://${publicIp}:5601" -ForegroundColor White
Write-Host ""
Write-Host "  ?? Order Service API:" -ForegroundColor Cyan
Write-Host "     http://${publicIp}:8080" -ForegroundColor White
Write-Host "     http://${publicIp}:8080/swagger" -ForegroundColor White
Write-Host "     http://${publicIp}:8080/health" -ForegroundColor White
Write-Host ""
Write-Host "  ?? SSH Access:" -ForegroundColor Cyan
Write-Host "     ssh ${AdminUsername}@${publicIp}" -ForegroundColor White
Write-Host ""
Write-Host "???????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "?? Useful Commands:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  # SSH to VM" -ForegroundColor Gray
Write-Host "  ssh ${AdminUsername}@${publicIp}" -ForegroundColor White
Write-Host ""
Write-Host "  # View all pods" -ForegroundColor Gray
Write-Host "  kubectl get pods -A" -ForegroundColor White
Write-Host ""
Write-Host "  # View application logs" -ForegroundColor Gray
Write-Host "  kubectl logs -n microservices -l app=order-service -f" -ForegroundColor White
Write-Host ""
Write-Host "  # Test API" -ForegroundColor Gray
Write-Host "  curl http://${publicIp}:8080/health" -ForegroundColor White
Write-Host ""
Write-Host "???????????????????????????????????????????????????????????????" -ForegroundColor Cyan
Write-Host ""
Write-Host "? Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Open browser: http://${publicIp}:5601 (Kibana)" -ForegroundColor White
Write-Host "  2. Open browser: http://${publicIp}:8080/swagger (API)" -ForegroundColor White
Write-Host "  3. Create test orders via Swagger UI" -ForegroundColor White
Write-Host "  4. View logs in Kibana (create index pattern: fluent-bit-*)" -ForegroundColor White
Write-Host ""
Write-Host "?? For more details, see DEPLOYMENT-AZURE-VM.md" -ForegroundColor Gray
Write-Host ""
