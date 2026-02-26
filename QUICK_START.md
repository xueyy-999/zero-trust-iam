# 快速开始

## 5 分钟快速部署

### 1. 修改配置（2 分钟）

```bash
# 编辑 inventory - 改为你的 CentOS IP
vim ansible/inventory/hosts.ini
# 改这一行：ansible_host=192.168.56.10

# 编辑变量 - 改密码
vim ansible/group_vars/all.yml
# 改这三行：
# mysql_root_password: "your_password"
# keycloak_admin_password: "your_password"
# risk_service_image: "your-registry/risk-service:latest"
```

### 2. 构建镜像（2 分钟）

```bash
cd services/risk-service
docker build -t your-registry/risk-service:latest .
docker push your-registry/risk-service:latest
```

### 3. 运行部署（1 分钟）

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00-all.yml
```

等待 10-15 分钟...

### 4. 验证

```bash
kubectl -n security get all
```

## 项目结构

```
.
├── README.md                    # 项目概述
├── QUICK_START.md              # 本文件
├── USAGE.md                    # 部署与使用指南
├── TEST_API.md                 # API 测试示例
├── ansible/
│   ├── inventory/hosts.ini     # 主机配置（改这里）
│   ├── group_vars/all.yml      # 全局变量（改这里）
│   └── playbooks/
│       ├── 00-all.yml          # 主 playbook
│       ├── 01-k8s.yml          # Kubernetes 安装
│       └── 10-apps.yml         # 应用部署
├── services/risk-service/      # Risk Service 源码
│   ├── main.go
│   ├── Dockerfile
│   └── go.mod
├── opa/policies/
│   └── abac.rego               # OPA 授权策略
└── docs/
    ├── INDEX.md                # 文档索引
    ├── 项目/                   # 项目总结与改进
    ├── 论文/                   # 论文相关
    ├── 答辩/                   # 答辩相关
    └── 零信任IAM/
        └── TASK_零信任IAM.md
```
.
├── README.md                    # 项目概述
├── USAGE.md               # 详细部署指南
├── QUICK_START.md             # 本文件
├── ansible/
│   ├── inventory/hosts.ini     # 主机配置（改这里）
│   ├── group_vars/all.yml      # 全局变量（改这里）
│   └── playbooks/
│       ├── 00-all.yml          # 主 playbook
│       ├── 01-k8s.yml          # Kubernetes 安装
│       └── 10-apps.yml         # 应用部署
├── services/risk-service/      # Risk Service 源码
│   ├── main.go
│   ├── Dockerfile
│   └── go.mod
├── opa/policies/
│   └── abac.rego               # OPA 授权策略
└── docs/零信任IAM/
    └── TASK_零信任IAM.md       # 功能清单
```

## 核心服务

| 服务 | 端口 | 用途 |
|------|------|------|
| Keycloak | 8080 | 身份认证 (OIDC) |
| OPA | 8181 | 授权策略引擎 |
| Risk Service | 8080 | 风险评分 |
| MySQL | 3306 | 数据存储 |

## 常用命令

```bash
# 查看所有 Pod
kubectl -n security get pods

# 查看 Pod 日志
kubectl -n security logs -f deployment/keycloak

# 进入 Pod
kubectl -n security exec -it deployment/keycloak -- /bin/bash

# 删除所有资源
kubectl delete namespace security

# 查看 Keycloak 管理界面
# http://CENTOS_IP:8080/admin
# 用户: admin
# 密码: (在 all.yml 中设置)
```

## 测试 Risk Service

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

## 故障排查

**Pod 无法启动？**
```bash
kubectl -n security describe pod <pod-name>
kubectl -n security logs <pod-name>
```

**镜像拉取失败？**
- 检查 `risk_service_image` 是否正确
- 确保镜像已推送到仓库

**网络连接问题？**
- 检查防火墙是否开放了 8080, 8181, 3306 端口
- 检查 CentOS IP 是否正确

## 更多信息

- 详细部署指南：USAGE.md
- 功能清单：docs/零信任IAM/TASK_零信任IAM.md




