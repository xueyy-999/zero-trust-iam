# 部署指南

## 前置条件

1. **CentOS 9 虚拟机**
   - 4GB+ 内存
   - 20GB+ 磁盘
   - 网络连接

2. **Ansible 控制机**（Windows/Linux/Mac）
   - 安装 Ansible 2.9+
   - 能 SSH 连接到 CentOS

## 部署步骤

### 1. 准备配置

编辑 `ansible/inventory/hosts.ini`，改为你的 CentOS IP：

```ini
[k8s_master]
master1 ansible_host=YOUR_CENTOS_IP ansible_user=root
```

编辑 `ansible/group_vars/all.yml`，改密码和镜像：

```yaml
mysql_root_password: "your_strong_password"
keycloak_admin_password: "your_strong_password"
risk_service_image: "your-registry/risk-service:latest"
```

### 2. 构建 Risk Service 镜像

在 Windows 上：

```bash
cd services/risk-service
docker build -t your-registry/risk-service:latest .
docker push your-registry/risk-service:latest
```

或使用 Docker Hub：

```bash
docker build -t yourusername/risk-service:latest .
docker push yourusername/risk-service:latest
```

然后更新 `ansible/group_vars/all.yml` 中的 `risk_service_image`。

### 3. 运行 Ansible 部署

从 Ansible 控制机执行：

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00-all.yml
```

部署过程约 10-15 分钟。

### 4. 验证部署

在 CentOS 上检查：

```bash
# 检查节点
kubectl get nodes

# 检查 security 命名空间中的资源
kubectl -n security get all

# 查看 Pod 日志
kubectl -n security logs -f deployment/keycloak
kubectl -n security logs -f deployment/opa
kubectl -n security logs -f deployment/risk-service
```

## 访问服务

### Keycloak 管理界面

```
http://CENTOS_IP:8080/admin
用户名: admin
密码: (在 all.yml 中设置)
```

### Risk Service API

```bash
# 健康检查
curl http://CENTOS_IP:8080/health

# 风险评分
curl -X POST http://CENTOS_IP:8080/score \
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

### OPA 策略引擎

```bash
# 查询授权
curl -X POST http://CENTOS_IP:8181/v1/data/authz/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "sub": "user123",
      "roles": ["user"],
      "resource": "orders",
      "action": "read",
      "score": 30
    }
  }'
```

## 故障排查

### Pod 无法启动

```bash
# 查看 Pod 状态
kubectl -n security describe pod <pod-name>

# 查看日志
kubectl -n security logs <pod-name>
```

### 镜像拉取失败

确保 `risk_service_image` 在 `all.yml` 中正确设置，且镜像已推送到仓库。

### 网络连接问题

检查防火墙规则，确保以下端口开放：
- 6443 (Kubernetes API)
- 8080 (Keycloak, Risk Service)
- 8181 (OPA)
- 3306 (MySQL)

## 清理

删除所有资源：

```bash
kubectl delete namespace security
```

## 更多信息

- README.md - 项目概述
- docs/零信任IAM/TASK_零信任IAM.md - 功能清单

