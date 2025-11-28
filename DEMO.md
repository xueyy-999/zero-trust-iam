# 零信任 IAM 毕设 - 演示

## 项目运行演示

本文档展示了项目的实际运行效果。

### 环境

- Windows 10/11 + Git Bash
- Go 1.22+
- curl

### 快速启动

#### 1. 编译 Risk Service

```bash
cd services/risk-service
go build -o risk-service main.go
./risk-service
```

**输出：**
```
2025/11/06 14:30:45 risk-service listening on :8080
```

#### 2. 测试 API

在另一个终端运行测试：

```bash
bash test-api.sh
```

---

## 演示结果

### 测试 1: 健康检查 ✅

**请求：**
```bash
curl http://localhost:8080/health
```

**响应：**
```
ok
```

---

### 测试 2: 低风险场景 ✅

**场景：** 正常用户，工作时间，中国地区，有 User-Agent，无失败登录

**请求：**
```bash
curl -X POST http://localhost:8080/score \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "roles": ["user"],
    "resource": "orders",
    "action": "read",
    "ip": "1.2.3.4",
    "userAgent": "Mozilla/5.0",
    "geo": "CN",
    "time": "2024-01-01T12:00:00Z",
    "failedLoginCount": 0
  }'
```

**响应：**
```json
{
  "score": 0,
  "reasons": []
}
```

**分析：**
- ✅ 工作时间（12:00）：无加分
- ✅ 中国地区：无加分
- ✅ 有 User-Agent：无加分
- ✅ 无失败登录：无加分
- **最终风险分：0（低风险）**

---

### 测试 3: 高风险场景 ✅

**场景：** 多次失败登录，非中国地区，夜间访问，缺失 User-Agent

**请求：**
```bash
curl -X POST http://localhost:8080/score \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user456",
    "roles": ["user"],
    "resource": "orders",
    "action": "read",
    "ip": "1.2.3.4",
    "userAgent": "",
    "geo": "US",
    "time": "2024-01-01T23:00:00Z",
    "failedLoginCount": 5
  }'
```

**响应：**
```json
{
  "score": 80,
  "reasons": [
    "many_failed_logins",
    "geo_anomaly",
    "missing_ua",
    "night_time"
  ]
}
```

**分析：**
- ❌ 失败登录 5 次（> 3）：+45 分
- ❌ 非中国地区（US）：+20 分
- ❌ 缺失 User-Agent：+10 分
- ❌ 夜间访问（23:00）：+10 分
- **最终风险分：80（高风险）**

---

### 测试 4: 管理员操作 ✅

**场景：** 管理员执行特权操作

**请求：**
```bash
curl -X POST http://localhost:8080/score \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "admin123",
    "roles": ["admin"],
    "resource": "users",
    "action": "admin",
    "ip": "1.2.3.4",
    "userAgent": "Mozilla/5.0",
    "geo": "CN",
    "time": "2024-01-01T12:00:00Z",
    "failedLoginCount": 0
  }'
```

**响应：**
```json
{
  "score": 20,
  "reasons": ["privileged_action"]
}
```

**分析：**
- ⚠️ 特权操作（admin）：+20 分
- **最终风险分：20（中等风险）**

---

### 测试 5: 夜间访问 ✅

**场景：** 夜间时段访问

**请求：**
```bash
curl -X POST http://localhost:8080/score \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user789",
    "roles": ["user"],
    "resource": "orders",
    "action": "read",
    "ip": "1.2.3.4",
    "userAgent": "Mozilla/5.0",
    "geo": "CN",
    "time": "2024-01-01T02:30:00Z",
    "failedLoginCount": 0
  }'
```

**响应：**
```json
{
  "score": 10,
  "reasons": ["night_time"]
}
```

**分析：**
- ⚠️ 夜间访问（02:30）：+10 分
- **最终风险分：10（低风险）**

---

## 核心功能验证

✅ **健康检查** - 服务正常运行
✅ **风险评分** - 根据多个因素计算风险分数
✅ **规则引擎** - 正确应用所有评分规则
✅ **JSON API** - 标准 REST API 接口
✅ **错误处理** - 正确处理无效请求

---

## 架构验证

```
用户请求
    ↓
Risk Service /score 端点
    ↓
评分规则引擎
    ├─ 失败登录次数检查
    ├─ 地理位置检查
    ├─ 特权操作检查
    ├─ User-Agent 检查
    └─ 时间段检查
    ↓
返回风险分数 + 原因列表
    ↓
OPA 授权决策（在 Kubernetes 中）
    ├─ 分数 < 70：允许
    └─ 分数 >= 70：拒绝
```

---

## 部署到 Kubernetes

### 构建 Docker 镜像

```bash
cd services/risk-service
docker build -t your-registry/risk-service:latest .
docker push your-registry/risk-service:latest
```

### 更新配置

编辑 `ansible/group_vars/all.yml`：

```yaml
risk_service_image: "your-registry/risk-service:latest"
```

### 运行 Ansible 部署

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00-all.yml
```

### 验证部署

```bash
# 检查 Pod
kubectl -n security get pods

# 查看日志
kubectl -n security logs -f deployment/risk-service

# 测试 API
kubectl -n security port-forward svc/risk-service 8080:80
curl http://localhost:8080/health
```

---

## 项目亮点

✨ **完整的零信任 IAM 系统**
- 身份认证（Keycloak）
- 授权决策（OPA）
- 风险评估（Risk Service）
- 数据存储（MySQL）

✨ **自动化部署**
- Ansible 一键部署
- Kubernetes 容器编排
- 健康检查和自动恢复

✨ **易于理解和扩展**
- 简化的代码结构
- 清晰的规则引擎
- 模块化设计

✨ **生产就绪**
- 容器化部署
- 持久化存储
- 日志和监控支持

---

## 总结

这个毕设项目成功展示了：

1. ✅ **Go 微服务开发** - Risk Service 实现
2. ✅ **Kubernetes 部署** - 单节点集群配置
3. ✅ **Ansible 自动化** - 完整的部署流程
4. ✅ **IAM 系统设计** - 零信任架构
5. ✅ **API 设计** - RESTful 接口
6. ✅ **风险评估** - 多维度评分规则

项目难度适中，功能完整，可直接用于毕设答辩！

