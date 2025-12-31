# Microservices Logging Demo

本项目演示如何在本地 Kubernetes 环境中搭建完整的日志收集系统，将微服务日志存储到 Elasticsearch 并通过 Kibana 进行可视化。

## 📚 文档导航

> 📖 **完整文档索引**: [DOCS_INDEX.md](DOCS_INDEX.md) - 查看所有文档的详细导航

### 入门文档
- **[QUICKSTART.md](QUICKSTART.md)** - 5 分钟快速入门指南
- **[USER_MANUAL.md](USER_MANUAL.md)** - 详细用户手册

### 教程和参考
- **[KIBANA_QUERY_TUTORIAL.md](KIBANA_QUERY_TUTORIAL.md)** - Kibana 日志查询完整教程
- **[KIBANA_QUERY_CHEATSHEET.md](KIBANA_QUERY_CHEATSHEET.md)** - Kibana 查询语法速查表
- **[PORT_FORWARD_TROUBLESHOOTING.md](PORT_FORWARD_TROUBLESHOOTING.md)** - 端口转发故障排查指南

### 架构和故障排除
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - 系统架构设计文档
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - 常见问题解决方案

## 🚀 快速开始

### 部署步骤

#### Linux/Mac
```bash
cd OrderService
chmod +x scripts/*.sh
./scripts/deploy.sh
```

#### Windows (PowerShell)
```powershell
cd OrderService
.\scripts\deploy.ps1
```

### 启动端口转发

```bash
# Kibana
kubectl port-forward -n logging svc/kibana 5601:5601

# Order Service
kubectl port-forward -n microservices svc/order-service 8080:80
```

## 🌐 访问服务

- **Kibana**: http://localhost:5601 - 日志查询和可视化
- **Order Service Swagger**: http://localhost:8080/swagger - API 文档和测试
- **Elasticsearch**: http://localhost:9200 - 日志存储

## 📊 项目架构

```
Order Service (2副本) → Fluent Bit → Elasticsearch → Kibana
```

**详细架构说明**: 查看 [ARCHITECTURE.md](ARCHITECTURE.md)

## 🛠️ 技术栈

- **.NET 10** - 微服务开发框架
- **Kubernetes** - 容器编排平台
- **Elasticsearch 8.11** - 日志存储和搜索引擎
- **Fluent Bit 2.2** - 轻量级日志采集器
- **Kibana 8.11** - 日志可视化和分析

## 📋 功能特性

- ✅ 结构化 JSON 日志输出
- ✅ Correlation ID 追踪请求链路
- ✅ 自动注入 Kubernetes 元数据
- ✅ 集中式日志存储（Elasticsearch）
- ✅ 可视化日志分析（Kibana）
- ✅ 多副本微服务部署
- ✅ 健康检查和就绪探测

## 🔍 快速查询示例

在 Kibana 中查询日志：

```
# 查看所有错误日志
log.level: "Error"

# 追踪特定请求
CorrelationId: "your-correlation-id"

# 查看特定 Pod 的日志
k8s_pod_name: "order-service*"
```

**完整查询教程**: [KIBANA_QUERY_TUTORIAL.md](KIBANA_QUERY_TUTORIAL.md)

## 🧪 测试脚本

生成测试日志数据：

```powershell
# Windows
.\scripts\test.ps1

# Linux/Mac
./scripts/test.sh
```

## 🔧 故障排查

如果遇到问题：

```powershell
# Windows
.\scripts\troubleshoot.ps1

# Linux/Mac
./scripts/status.sh
```

查看详细故障排查指南: [PORT_FORWARD_TROUBLESHOOTING.md](PORT_FORWARD_TROUBLESHOOTING.md)

## 🧹 清理环境

```powershell
# Windows
.\scripts\cleanup.ps1

# Linux/Mac
./scripts/cleanup.sh
```

## 📝 许可证

MIT License
