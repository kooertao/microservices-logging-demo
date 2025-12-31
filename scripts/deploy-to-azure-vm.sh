#!/bin/bash

# Azure VM ??????? - Bash ??

set -e

# ????
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ????
RESOURCE_GROUP="${1:-microservices-logging-rg}"
VM_NAME="${2:-microservices-vm}"
LOCATION="${3:-eastus}"
VM_SIZE="${4:-Standard_D4s_v3}"
ADMIN_USERNAME="azureuser"

echo -e "${CYAN}?? Starting Azure VM deployment...${NC}"
echo ""

# ????????
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ?? Azure CLI
if ! command_exists az; then
    echo -e "${RED}? Azure CLI not found. Please install it first.${NC}"
    echo -e "${YELLOW}   Download from: https://docs.microsoft.com/cli/azure/install-azure-cli${NC}"
    exit 1
fi

# ?? Docker
if ! command_exists docker; then
    echo -e "${RED}? Docker not found. Please install Docker first.${NC}"
    exit 1
fi

echo -e "${GREEN}[1/10] Checking Azure login status...${NC}"
if ! az account show >/dev/null 2>&1; then
    echo -e "${YELLOW}??  Not logged in to Azure. Logging in...${NC}"
    az login
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}? Logged in to subscription: $SUBSCRIPTION${NC}"
echo ""

# ?????
echo -e "${GREEN}[2/10] Creating resource group: $RESOURCE_GROUP...${NC}"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo -e "${GREEN}? Resource group created${NC}"
echo ""

# ??????
echo -e "${GREEN}[3/10] Creating virtual network...${NC}"
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${VM_NAME}-vnet" \
    --address-prefix 10.0.0.0/16 \
    --subnet-name default \
    --subnet-prefix 10.0.1.0/24 \
    --output none
echo -e "${GREEN}? Virtual network created${NC}"
echo ""

# ???????
echo -e "${GREEN}[4/10] Creating network security group with rules...${NC}"
az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${VM_NAME}-nsg" \
    --output none

# ??????
declare -A rules=(
    ["allow-ssh"]="100:22"
    ["allow-http"]="110:80"
    ["allow-https"]="120:443"
    ["allow-kibana"]="130:5601"
    ["allow-order-service"]="140:8080"
)

for rule_name in "${!rules[@]}"; do
    IFS=':' read -r priority port <<< "${rules[$rule_name]}"
    az network nsg rule create \
        --resource-group "$RESOURCE_GROUP" \
        --nsg-name "${VM_NAME}-nsg" \
        --name "$rule_name" \
        --priority "$priority" \
        --source-address-prefixes '*' \
        --destination-port-ranges "$port" \
        --access Allow \
        --protocol Tcp \
        --output none
done
echo -e "${GREEN}? Network security group created with rules${NC}"
echo ""

# ???? IP
echo -e "${GREEN}[5/10] Creating public IP address...${NC}"
az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "${VM_NAME}-ip" \
    --sku Standard \
    --allocation-method Static \
    --output none
echo -e "${GREEN}? Public IP created${NC}"
echo ""

# ?????
echo -e "${GREEN}[6/10] Creating virtual machine (this may take a few minutes)...${NC}"
az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --image Ubuntu2204 \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USERNAME" \
    --generate-ssh-keys \
    --public-ip-address "${VM_NAME}-ip" \
    --nsg "${VM_NAME}-nsg" \
    --vnet-name "${VM_NAME}-vnet" \
    --subnet default \
    --os-disk-size-gb 128 \
    --storage-sku Premium_LRS \
    --output none

echo -e "${GREEN}? Virtual machine created${NC}"
echo ""

# ???? IP
echo -e "${GREEN}[7/10] Getting VM public IP address...${NC}"
PUBLIC_IP=$(az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --query publicIps \
    --output tsv)

echo -e "${GREEN}? VM Public IP: $PUBLIC_IP${NC}"
echo ""

# ?? Docker ??
echo -e "${GREEN}[8/10] Building Docker image...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$PROJECT_ROOT")"

cd "$PARENT_DIR"
docker build -t order-service:latest -f OrderService/Dockerfile . --quiet
cd "$PROJECT_ROOT"

echo -e "${GREEN}? Docker image built${NC}"
echo ""

# ????
echo -e "${GREEN}[9/10] Saving and transferring Docker image to VM...${NC}"
docker save order-service:latest -o order-service.tar

# ?? VM ????
echo -e "${YELLOW}? Waiting for VM to be ready...${NC}"
sleep 30

# ????? VM
echo -e "${YELLOW}? Transferring image to VM (this may take a few minutes)...${NC}"
scp -o StrictHostKeyChecking=no order-service.tar "${ADMIN_USERNAME}@${PUBLIC_IP}:~/"

# ?? k8s ??
echo -e "${YELLOW}? Transferring Kubernetes configurations...${NC}"
scp -o StrictHostKeyChecking=no -r "$PROJECT_ROOT/OrderService/k8s" "${ADMIN_USERNAME}@${PUBLIC_IP}:~/"

# ????????
rm -f order-service.tar

echo -e "${GREEN}? Files transferred to VM${NC}"
echo ""

# ? VM ????????
echo -e "${GREEN}[10/10] Installing dependencies and deploying application on VM...${NC}"

ssh -o StrictHostKeyChecking=no "${ADMIN_USERNAME}@${PUBLIC_IP}" 'bash -s' << 'ENDSSH'
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
ENDSSH

echo -e "${GREEN}? Installation and deployment completed!${NC}"
echo ""

# ??????
cat << EOF
${CYAN}???????????????????????????????????????????????????????????????${NC}
${GREEN}?? Deployment Successful!${NC}
${CYAN}???????????????????????????????????????????????????????????????${NC}

${YELLOW}?? Access Information:${NC}

  ???  VM Public IP: ${PUBLIC_IP}

  ${CYAN}?? Kibana (Logs Dashboard):${NC}
     http://${PUBLIC_IP}:5601

  ${CYAN}?? Order Service API:${NC}
     http://${PUBLIC_IP}:8080
     http://${PUBLIC_IP}:8080/swagger
     http://${PUBLIC_IP}:8080/health

  ${CYAN}?? SSH Access:${NC}
     ssh ${ADMIN_USERNAME}@${PUBLIC_IP}

${CYAN}???????????????????????????????????????????????????????????????${NC}

${YELLOW}?? Useful Commands:${NC}

  # SSH to VM
  ssh ${ADMIN_USERNAME}@${PUBLIC_IP}

  # View all pods
  kubectl get pods -A

  # View application logs
  kubectl logs -n microservices -l app=order-service -f

  # Test API
  curl http://${PUBLIC_IP}:8080/health

${CYAN}???????????????????????????????????????????????????????????????${NC}

${YELLOW}? Next Steps:${NC}
  1. Open browser: http://${PUBLIC_IP}:5601 (Kibana)
  2. Open browser: http://${PUBLIC_IP}:8080/swagger (API)
  3. Create test orders via Swagger UI
  4. View logs in Kibana (create index pattern: fluent-bit-*)

?? For more details, see DEPLOYMENT-AZURE-VM.md

EOF
