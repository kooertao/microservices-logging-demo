# Kubernetes Infrastructure

This directory contains the common infrastructure components for the microservices logging demo.

## Components

1. **00-namespace.yaml** - Defines namespaces for logging and microservices
2. **01-elasticsearch.yaml** - Elasticsearch StatefulSet and Service for log storage
3. **02-kibana.yaml** - Kibana Deployment and Service for log visualization
4. **03-fluent-bit-rbac.yaml** - RBAC configuration for Fluent Bit
5. **04-fluent-bit-configmap.yaml** - Fluent Bit configuration
6. **05-fluent-bit-daemonset.yaml** - Fluent Bit DaemonSet for log collection

## Deployment Order

Deploy the infrastructure components in the following order:

```bash
# 1. Create namespaces
kubectl apply -f 00-namespace.yaml

# 2. Deploy Elasticsearch
kubectl apply -f 01-elasticsearch.yaml

# 3. Wait for Elasticsearch to be ready
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s

# 4. Deploy Kibana
kubectl apply -f 02-kibana.yaml

# 5. Deploy Fluent Bit RBAC
kubectl apply -f 03-fluent-bit-rbac.yaml

# 6. Deploy Fluent Bit ConfigMap
kubectl apply -f 04-fluent-bit-configmap.yaml

# 7. Deploy Fluent Bit DaemonSet
kubectl apply -f 05-fluent-bit-daemonset.yaml
```

Or deploy all at once:

```bash
kubectl apply -f .
```

## Accessing Kibana

After deployment, get the Kibana service URL:

```bash
# For LoadBalancer type (default)
kubectl get service kibana -n logging

# Or use port-forward
kubectl port-forward -n logging svc/kibana 5601:5601
```

Then access Kibana at http://localhost:5601

## Service Dependencies

The microservices (OrderService, InventoryService) depend on these infrastructure components being deployed first. They will automatically send logs to the logging stack through Fluent Bit.

## Notes

- Elasticsearch is configured as a single-node cluster suitable for development/demo purposes
- Fluent Bit is deployed as a DaemonSet to collect logs from all nodes
- The logging namespace is separate from the microservices namespace for better isolation
