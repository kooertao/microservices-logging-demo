# 故障排除指南

## 常见问题

### Pod 无法启动

```bash
# 查看 Pod 状态
kubectl get pods -n logging
kubectl get pods -n microservices

# 查看详细信息
kubectl describe pod <pod-name> -n <namespace>

# 查看日志
kubectl logs <pod-name> -n <namespace>
```

### Pod 一直 Pending

**原因**: 存储类不可用

**解决**: 创建存储类
```bash
kubectl get storageclass
```

### Kibana 中没有日志

**检查步骤**:

1. 确认时间范围设置
2. 检查 Fluent Bit 运行状态
3. 查看 Elasticsearch 索引
4. 刷新 Kibana 索引模式

```bash
kubectl logs -n logging -l app=fluent-bit
curl http://localhost:9200/_cat/indices?v
```

### 端口转发断开

**解决**: 重新启动端口转发
```bash
kubectl port-forward -n logging svc/kibana 5601:5601
```

### Elasticsearch 磁盘满

```bash
# 删除旧索引
curl -X DELETE http://localhost:9200/logs-microservices-2024.01.01

# 查看磁盘使用
kubectl exec -n logging <es-pod> -- df -h
```

### Fluent Bit 连接失败

```bash
# 检查 Elasticsearch 服务
kubectl get svc -n logging elasticsearch

# 测试连接
kubectl exec -n logging <fluent-bit-pod> -- curl elasticsearch.logging.svc.cluster.local:9200
```

## 调试技巧

### 查看日志
```bash
kubectl logs -n <namespace> <pod-name> -f
kubectl logs -n <namespace> <pod-name> --previous
```

### 进入容器
```bash
kubectl exec -it -n <namespace> <pod-name> -- /bin/bash
```

### 查看事件
```bash
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

### 查看资源使用
```bash
kubectl top pods -n logging
kubectl top pods -n microservices
```

## 获取帮助

1. 查看文档: [README.md](README.md)
2. 运行状态检查: ./scripts/status.sh
3. 收集诊断信息

```bash
kubectl get pods -A
kubectl logs -n logging --all-containers=true
```
