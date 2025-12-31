# 快速入门指南

本指南帮助你在 5 分钟内完成部署并查看日志。

## 前提条件

- Docker Desktop 已安装并运行
- Kubernetes 已启用
- kubectl 命令可用

## 快速部署

### Linux/Mac
```bash
cd OrderService
chmod +x scripts/*.sh
./scripts/deploy.sh
```

### Windows (PowerShell)
```powershell
cd OrderService
.\scripts\deploy.ps1
```

## 启动端口转发

在新的终端窗口中运行以下命令：

### Kibana 端口转发
```bash
# Linux/Mac/Windows
kubectl port-forward -n logging svc/kibana 5601:5601
```

### Order Service 端口转发
```bash
# Linux/Mac/Windows
kubectl port-forward -n microservices svc/order-service 8080:80
```

> **注意**: Service 端口是 80，容器端口是 8080。端口转发将本地 8080 映射到 Service 的 80 端口。

## 访问服务

- **Kibana**: http://localhost:5601
- **Order Service Swagger**: http://localhost:8080/swagger
- **Order Service Health**: http://localhost:8080/health
- **Elasticsearch**: http://localhost:9200

## 配置 Kibana

### Linux/Mac
```bash
./scripts/setup-kibana.sh
```

### Windows (PowerShell)
```powershell
.\scripts\setup-kibana.ps1
```

这将自动创建索引模式: `logs-microservices-*`

## 生成测试日志

### Linux/Mac
```bash
./scripts/test.sh
```

### Windows (PowerShell)
```powershell
.\scripts\test.ps1
```

## 在 Kibana 查看日志

1. 访问 http://localhost:5601
2. 点击左侧菜单的 "Discover"
3. 选择索引模式 `logs-microservices-*`
4. 查看实时日志流

> 📚 **详细查询教程**: 查看 [KIBANA_QUERY_TUTORIAL.md](KIBANA_QUERY_TUTORIAL.md) 了解完整的 Kibana 查询语法和实用示例

## 常用搜索查询

在 Kibana Discover 页面的搜索框中输入：

```
k8s_namespace_name: "microservices"
log.level: "Error"
CorrelationId: "your-id"
k8s_pod_name: "order-service*"
```

**更多查询示例请参考**: [KIBANA_QUERY_TUTORIAL.md](KIBANA_QUERY_TUTORIAL.md)

## 故障排查

如果无法访问服务，请运行故障排查脚本：

### Linux/Mac
```bash
./scripts/status.sh
```

### Windows (PowerShell)
```powershell
.\scripts\troubleshoot.ps1
```

### 常见问题

1. **无法访问 Swagger (http://localhost:8080/swagger)**
   - 确认端口转发命令正在运行
   - 检查 Pod 状态: `kubectl get pods -n microservices`
   - 查看 Pod 日志: `kubectl logs -n microservices -l app=order-service`
   - 验证 Service: `kubectl get svc -n microservices order-service`

2. **Pod 一直处于 Pending 状态**
   - 检查 Docker Desktop Kubernetes 是否已启用
   - 查看 Pod 详情: `kubectl describe pod -n microservices -l app=order-service`

3. **镜像拉取失败**
   - 确保已构建 Docker 镜像: `docker images | grep order-service`
   - 重新构建: `docker build -t order-service:latest -f OrderService/Dockerfile .`

4. **Kibana 无法显示日志**
   - 确认 Elasticsearch 运行正常: `kubectl get pods -n logging`
   - 检查索引是否创建: `curl http://localhost:9200/_cat/indices?v`
   - 运行 Kibana 设置脚本重新配置

## 清理环境

### Linux/Mac
```bash
./scripts/cleanup.sh
```

### Windows (PowerShell)
```powershell
.\scripts\cleanup.ps1
```

## 下一步

查看完整文档以了解更多功能:
- [README.md](README.md) - 项目概述和架构
- [USER_MANUAL.md](USER_MANUAL.md) - 详细用户手册
