# 系统架构说明

## 整体架构

```
Order Service (2 replicas)
    ↓ JSON 日志
Fluent Bit (DaemonSet)
    ↓ 收集 + K8s 元数据
Elasticsearch (StatefulSet)
    ↓ 存储和索引
Kibana (Web UI)
```

## 组件说明

### Order Service
- .NET 10 微服务
- JSON 结构化日志
- Correlation ID 追踪

### Fluent Bit
- DaemonSet 部署（每个节点一个）
- 自动收集容器日志
- 添加 Kubernetes 元数据
- 转发到 Elasticsearch

### Elasticsearch
- StatefulSet 部署
- 持久化存储（PVC）
- 日志索引和搜索

### Kibana
- Web 可视化界面
- 日志查询和分析
- 仪表板创建

## 数据流

1. Order Service 输出 JSON 日志到 stdout
2. Fluent Bit 收集日志并添加元数据
3. 日志发送到 Elasticsearch 存储
4. Kibana 从 Elasticsearch 查询展示

## 日志字段

### 应用字段
- @timestamp: 时间戳
- log.level: 日志级别
- message: 日志消息
- CorrelationId: 关联 ID

### Kubernetes 字段
- k8s_namespace_name: 命名空间
- k8s_pod_name: Pod 名称
- k8s_container_name: 容器名称
- k8s_labels_*: Pod 标签

## 资源配置

### Elasticsearch
- CPU: 500m / 1000m
- Memory: 1Gi / 2Gi
- Storage: 5Gi

### Kibana
- CPU: 250m / 500m
- Memory: 512Mi / 1Gi

### Fluent Bit
- CPU: 100m / 500m
- Memory: 128Mi / 256Mi

### Order Service
- CPU: 100m / 200m
- Memory: 128Mi / 256Mi

## 生产环境建议

1. 启用 Elasticsearch 安全认证
2. 配置 TLS/SSL 加密
3. Elasticsearch 集群（3+ 节点）
4. 实施日志保留策略
5. 配置监控和告警
