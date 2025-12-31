# Azure VM ????

???????????????????? Azure VM ??

## ????

```
Azure VM (Ubuntu 22.04)
??? Docker Engine
??? Kubernetes (k3s ?????)
?   ??? Namespace: logging
?   ?   ??? Elasticsearch (?????)
?   ?   ??? Kibana (?????)
?   ?   ??? Fluent Bit (????)
?   ??? Namespace: microservices
?       ??? Order Service (.NET 10 ???)
??? ????? (?? 80, 443, 5601, 8080)
```

## ????

- Azure ????
- Azure CLI ????????
- ????? PowerShell ? Bash
- ????? Docker????????

## ????

### ?? 1: ?? Azure ??

#### 1.1 ?? Azure
```bash
az login
```

#### 1.2 ?????
```bash
az group create \
  --name microservices-logging-rg \
  --location eastus
```

#### 1.3 ??????
```bash
az network vnet create \
  --resource-group microservices-logging-rg \
  --name microservices-vnet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name default \
  --subnet-prefix 10.0.1.0/24
```

#### 1.4 ????????NSG?
```bash
# ?? NSG
az network nsg create \
  --resource-group microservices-logging-rg \
  --name microservices-nsg

# ?? SSH (22)
az network nsg rule create \
  --resource-group microservices-logging-rg \
  --nsg-name microservices-nsg \
  --name allow-ssh \
  --priority 100 \
  --source-address-prefixes '*' \
  --destination-port-ranges 22 \
  --access Allow \
  --protocol Tcp

# ?? HTTP (80)
az network nsg rule create \
  --resource-group microservices-logging-rg \
  --nsg-name microservices-nsg \
  --name allow-http \
  --priority 110 \
  --source-address-prefixes '*' \
  --destination-port-ranges 80 \
  --access Allow \
  --protocol Tcp

# ?? HTTPS (443)
az network nsg rule create \
  --resource-group microservices-logging-rg \
  --nsg-name microservices-nsg \
  --name allow-https \
  --priority 120 \
  --source-address-prefixes '*' \
  --destination-port-ranges 443 \
  --access Allow \
  --protocol Tcp

# ?? Kibana (5601)
az network nsg rule create \
  --resource-group microservices-logging-rg \
  --nsg-name microservices-nsg \
  --name allow-kibana \
  --priority 130 \
  --source-address-prefixes '*' \
  --destination-port-ranges 5601 \
  --access Allow \
  --protocol Tcp

# ?? Order Service (8080)
az network nsg rule create \
  --resource-group microservices-logging-rg \
  --nsg-name microservices-nsg \
  --name allow-order-service \
  --priority 140 \
  --source-address-prefixes '*' \
  --destination-port-ranges 8080 \
  --access Allow \
  --protocol Tcp
```

#### 1.5 ???? IP
```bash
az network public-ip create \
  --resource-group microservices-logging-rg \
  --name microservices-public-ip \
  --sku Standard \
  --allocation-method Static
```

#### 1.6 ?????
```bash
az vm create \
  --resource-group microservices-logging-rg \
  --name microservices-vm \
  --image Ubuntu2204 \
  --size Standard_D4s_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-address microservices-public-ip \
  --nsg microservices-nsg \
  --vnet-name microservices-vnet \
  --subnet default \
  --os-disk-size-gb 128 \
  --storage-sku Premium_LRS
```

??? VM ???
- **Standard_D4s_v3**: 4 vCPUs, 16 GB RAM??????????
- **Standard_B2ms**: 2 vCPUs, 8 GB RAM??????
- **Standard_D2s_v3**: 2 vCPUs, 8 GB RAM????????

### ?? 2: ?? VM ??

#### 2.1 ?? VM ?? IP
```bash
az vm show \
  --resource-group microservices-logging-rg \
  --name microservices-vm \
  --show-details \
  --query publicIps \
  --output tsv
```

#### 2.2 SSH ??? VM
```bash
ssh azureuser@<VM_PUBLIC_IP>
```

#### 2.3 ? VM ?????

```bash
# ????
sudo apt-get update && sudo apt-get upgrade -y

# ?? Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# ?? k3s???? Kubernetes?
curl -sfL https://get.k3s.io | sh -

# ?? kubectl ??
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# ????
kubectl get nodes

# ?????????? Docker ???
exit
```

?? SSH ???
```bash
ssh azureuser@<VM_PUBLIC_IP>
```

### ?? 3: ????? VM

#### 3.1 ???????? Docker ??

??????????? VM?

**?? A: ?? Azure Container Registry (??)**

```bash
# ????? ACR
az acr create \
  --resource-group microservices-logging-rg \
  --name microservicesacr<random-id> \
  --sku Basic

# ??? ACR
az acr login --name microservicesacr<random-id>

# ?? ACR ???????
ACR_LOGIN_SERVER=$(az acr show \
  --name microservicesacr<random-id> \
  --query loginServer \
  --output tsv)

# ???????
cd OrderService
docker build -t order-service:latest -f Dockerfile ..

# ????
docker tag order-service:latest ${ACR_LOGIN_SERVER}/order-service:latest

# ????? ACR
docker push ${ACR_LOGIN_SERVER}/order-service:latest

# ? VM ??? ACR ??
# SSH ? VM??????
az acr login --name microservicesacr<random-id>
```

**?? B: ??????????????**

```bash
# ???????
cd OrderService
docker build -t order-service:latest -f Dockerfile ..

# ????? tar ??
docker save order-service:latest -o order-service.tar

# ??? VM
scp order-service.tar azureuser@<VM_PUBLIC_IP>:~/

# SSH ? VM ?????
ssh azureuser@<VM_PUBLIC_IP>
docker load -i order-service.tar
```

#### 3.2 ?? Kubernetes ????? VM

```bash
# ???????????
scp -r OrderService/k8s azureuser@<VM_PUBLIC_IP>:~/
```

#### 3.3 ? VM ?????

SSH ? VM ????

```bash
cd ~/k8s

# ??????
kubectl apply -f 00-namespace.yaml

# ?? Elasticsearch
kubectl apply -f 01-elasticsearch.yaml
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

# ?? Kibana
kubectl apply -f 02-kibana.yaml
kubectl wait --for=condition=ready pod -l app=kibana -n logging --timeout=180s

# ?? Fluent Bit
kubectl apply -f 03-fluent-bit-rbac.yaml
kubectl apply -f 04-fluent-bit-configmap.yaml
kubectl apply -f 05-fluent-bit-daemonset.yaml
kubectl wait --for=condition=ready pod -l app=fluent-bit -n logging --timeout=180s

# ?? Order Service ??????? ACR?
# ?? 06-order-service.yaml?? image: order-service:latest 
# ?? image: <ACR_LOGIN_SERVER>/order-service:latest

# ?? Order Service
kubectl apply -f 06-order-service.yaml
kubectl wait --for=condition=ready pod -l app=order-service -n microservices --timeout=180s
```

### ?? 4: ??????

#### 4.1 ??????? NodePort ? LoadBalancer

??????????????

```bash
# ?? Kibana ??
kubectl patch svc kibana -n logging -p '{"spec":{"type":"NodePort","ports":[{"port":5601,"nodePort":30561}]}}'

# ?? Order Service ??
kubectl patch svc order-service -n microservices -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30080}]}}'
```

???? NodePort ?????

```bash
cat > ~/k8s/service-nodeport-overrides.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: logging
spec:
  type: NodePort
  selector:
    app: kibana
  ports:
    - port: 5601
      targetPort: 5601
      nodePort: 30561
---
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: microservices
spec:
  type: NodePort
  selector:
    app: order-service
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080
EOF

kubectl apply -f ~/k8s/service-nodeport-overrides.yaml
```

#### 4.2 ?? Nginx ???????????

```bash
# ?? Nginx
sudo apt-get install nginx -y

# ?? Nginx ??
sudo tee /etc/nginx/sites-available/microservices << 'EOF'
# Kibana
server {
    listen 5601;
    server_name _;
    
    location / {
        proxy_pass http://localhost:30561;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Order Service
server {
    listen 8080;
    server_name _;
    
    location / {
        proxy_pass http://localhost:30080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# ????
sudo ln -s /etc/nginx/sites-available/microservices /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### ?? 5: ????

#### 5.1 ???? Pod ??
```bash
kubectl get pods -A
```

#### 5.2 ????

???????
- **Kibana**: http://<VM_PUBLIC_IP>:5601
- **Order Service Swagger**: http://<VM_PUBLIC_IP>:8080/swagger
- **Order Service Health**: http://<VM_PUBLIC_IP>:8080/health

#### 5.3 ?????

```bash
# ??????
curl -X POST http://<VM_PUBLIC_IP>:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-123",
    "items": [
      {
        "productId": "prod-001",
        "productName": "Laptop",
        "quantity": 1,
        "unitPrice": 999.99
      }
    ],
    "totalAmount": 999.99
  }'

# ??????
kubectl logs -n microservices -l app=order-service -f

# ?? Fluent Bit ??
kubectl logs -n logging -l app=fluent-bit -f
```

#### 5.4 ?? Kibana

1. ?? http://<VM_PUBLIC_IP>:5601
2. ?? **Management > Stack Management > Index Management**
3. ?? Index Pattern: `fluent-bit-*`
4. ?? `@timestamp` ??????
5. ?? **Discover** ????

## ???????

?????????????????????

### ?? PowerShell ????

```powershell
# ??????
.\scripts\deploy-to-azure-vm.ps1 -ResourceGroup "microservices-logging-rg" -VmName "microservices-vm" -Location "eastus"
```

### ?? Bash ????

```bash
# ??????
./scripts/deploy-to-azure-vm.sh
```

## ?????

### ????????
```bash
# ??????
kubectl top nodes

# ?? Pod ??
kubectl top pods -A

# ??????
df -h
```

### ????
```bash
# ????
kubectl logs -n microservices deployment/order-service --tail=100 -f

# Elasticsearch ??
kubectl logs -n logging statefulset/elasticsearch --tail=100 -f

# Fluent Bit ??
kubectl logs -n logging daemonset/fluent-bit --tail=100 -f
```

### ????
```bash
# ?? Order Service ???
kubectl scale deployment order-service -n microservices --replicas=3

# ??????
kubectl get deployment order-service -n microservices
```

## ????

### ?? Kubernetes ??
```bash
kubectl delete namespace microservices
kubectl delete namespace logging
```

### ?? Azure ??
```bash
az group delete --name microservices-logging-rg --yes --no-wait
```

## ????

### Pod ????
```bash
# ?? Pod ??
kubectl describe pod <pod-name> -n <namespace>

# ????
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### ??????
```bash
# ???????
docker images | grep order-service

# ???? ACR?????
az acr login --name <acr-name>
```

### ??????
```bash
# ??????
kubectl get svc -A

# ?? Azure NSG ??
az network nsg rule list --resource-group microservices-logging-rg --nsg-name microservices-nsg -o table

# ?? Nginx ??
sudo systemctl status nginx
sudo nginx -t
```

### Elasticsearch ??????
```bash
# ??????
df -h

# ?????????? 7 ??
curl -X DELETE "localhost:9200/fluent-bit-$(date -d '7 days ago' '+%Y.%m.%d')"
```

## ??????

1. **???**
   - ?? Elasticsearch ????
   - ?? HTTPS/TLS
   - ?? Azure Key Vault ????
   - ???????????

2. **????**
   - ????? Kubernetes ???AKS?
   - ?? Elasticsearch ???3+ ???
   - ?? Azure Load Balancer
   - ??????

3. **??**
   - ?? Azure Monitor
   - ???????? (Application Insights)
   - ??????
   - ????????

4. **??**
   - ?? Elasticsearch ??
   - ?? Azure Backup
   - ????????

5. **????**
   - ????????Premium SSD?
   - ?? Elasticsearch ????
   - ?????????
   - ?? Azure CDN?????

## ????

- ?? **Azure Reserved VM Instances**??????????? 72% ???
- ??????????/????
- ?? **Azure Spot VMs** ?????????
- ????????
- ?????????

## ???

- ?? CI/CD ????Azure DevOps / GitHub Actions?
- ???????
- ??????????/??/???
- ?????????
- ????????

## ????

- [Azure VM ??](https://docs.microsoft.com/azure/virtual-machines/)
- [k3s ??](https://k3s.io/)
- [Elasticsearch ??](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Fluent Bit ??](https://docs.fluentbit.io/manual/)
