# 完整使用手册

本手册提供详细的操作指南。

## 环境准备

### 安装 Docker Desktop

1. 下载并安装 Docker Desktop
2. 启用 Kubernetes 功能
3. 验证: kubectl cluster-info

## 系统部署

### 使用 Makefile
```bash
make deploy
make status
make test
make clean
```

### 使用脚本
```bash
./scripts/deploy.sh
./scripts/status.sh
./scripts/test.sh
./scripts/cleanup.sh
```

## 访问服务

启动端口转发后访问：

- Kibana: http://localhost:5601
- Order Service: http://localhost:8080/swagger
- Elasticsearch: http://localhost:9200

## 在 Kibana 查看日志

1. 访问 Kibana
2. 配置索引模式: logs-microservices-*
3. 打开 Discover 查看日志

## 常用操作

### 查看日志
```bash
kubectl logs -n microservices -l app=order-service -f
kubectl logs -n logging -l app=fluent-bit -f
```

### 重启服务
```bash
kubectl rollout restart deployment order-service -n microservices
```

### 查看状态
```bash
kubectl get pods -n logging
kubectl get pods -n microservices
```

## 故障排查

查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## 相关文档

- [快速入门](QUICKSTART.md)
- [系统架构](ARCHITECTURE.md)
- [故障排除](TROUBLESHOOTING.md)
