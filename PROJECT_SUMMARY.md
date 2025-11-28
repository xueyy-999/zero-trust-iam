# 零信任 IAM 毕设 - 项目总结

## 项目概述

这是一个简化的零信任身份认证与授权系统，展示了如何在 Kubernetes 上集成多个开源组件实现完整的 IAM 解决方案。

## 核心组件

### 1. Kubernetes 集群
- **单节点部署**（kubeadm）
- **CNI**：Flannel
- **运行时**：containerd

### 2. Keycloak
- **功能**：OIDC 身份认证
- **部署**：Kubernetes Deployment
- **存储**：内存（开发模式）

### 3. OPA (Open Policy Agent)
- **功能**：授权策略引擎
- **策略**：ABAC（基于属性的访问控制）
- **规则**：
  - 允许 `read` 操作访问 `orders` 资源
  - 允许 `admin` 操作（需要 admin 角色）
  - 拒绝高风险请求（风险分 >= 70）

### 4. Risk Service
- **功能**：风险评分服务
- **语言**：Go
- **评分规则**：
  - 失败登录次数 > 3：+20-40 分
  - 非中国地区访问：+20 分
  - 管理员操作：+20 分
  - 缺失 User-Agent：+10 分
  - 夜间访问（22:00-06:00）：+10 分
  - 最终分数范围：0-100

### 5. MySQL
- **功能**：数据存储
- **用途**：审计日志、用户数据
- **存储**：PersistentVolumeClaim (10GB)

## 架构流程

```
用户请求
    ↓
Keycloak (身份认证)
    ↓
Risk Service (风险评分)
    ↓
OPA (授权决策)
    ↓
允许/拒绝
```

## 部署架构

```
CentOS 9 虚拟机
├── Kubernetes (kubeadm)
│   └── security 命名空间
│       ├── Keycloak Pod
│       ├── OPA Pod
│       ├── Risk Service Pod
│       └── MySQL Pod
└── 持久化存储
    └── MySQL 数据卷
```

## 文件结构

```
项目根目录
├── README.md                    # 项目概述
├── QUICK_START.md              # 快速开始指南
├── DEPLOYMENT.md               # 详细部署指南
├── PROJECT_SUMMARY.md          # 本文件
│
├── ansible/                    # Ansible 自动化部署
│   ├── inventory/hosts.ini     # 主机清单（需要修改）
│   ├── group_vars/all.yml      # 全局变量（需要修改）
│   └── playbooks/
│       ├── 00-all.yml          # 主 playbook
│       ├── 01-k8s.yml          # Kubernetes 安装
│       └── 10-apps.yml         # 应用部署
│
├── services/risk-service/      # Risk Service 源码
│   ├── main.go                 # 主程序
│   ├── Dockerfile              # Docker 镜像定义
│   └── go.mod                  # Go 模块定义
│
├── opa/policies/               # OPA 策略
│   └── abac.rego               # ABAC 授权规则
│
├── scripts/                    # 脚本
│   └── init_centos9.sh         # CentOS 初始化脚本
│
└── docs/零信任IAM/             # 文档
    └── TASK_零信任IAM.md       # 功能清单
```

## 部署流程

### 第 1 步：准备配置
- 修改 `ansible/inventory/hosts.ini` - 改为 CentOS IP
- 修改 `ansible/group_vars/all.yml` - 改密码和镜像

### 第 2 步：构建镜像
```bash
cd services/risk-service
docker build -t your-registry/risk-service:latest .
docker push your-registry/risk-service:latest
```

### 第 3 步：运行 Ansible
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00-all.yml
```

### 第 4 步：验证
```bash
kubectl -n security get all
```

## 关键特性

✅ **自动化部署**：Ansible 一键部署整个系统
✅ **容器化**：所有服务都运行在 Kubernetes 上
✅ **持久化存储**：MySQL 数据持久化
✅ **健康检查**：所有 Pod 都有 liveness 和 readiness probe
✅ **简化配置**：所有配置都在 `all.yml` 中集中管理
✅ **易于扩展**：模块化设计，易于添加新功能

## 学习价值

这个项目展示了：
1. **Kubernetes 部署**：如何使用 kubeadm 部署单节点集群
2. **Ansible 自动化**：如何使用 Ansible 自动化部署复杂系统
3. **微服务架构**：多个服务如何协作
4. **身份认证**：OIDC 协议的实现
5. **授权策略**：OPA 策略引擎的使用
6. **风险评估**：如何实现风险评分系统

## 后续扩展方向

- 添加审计日志记录到 MySQL
- 实现 Keycloak Realm 自动导入
- 添加 Ingress 配置用于外部访问
- 集成 Prometheus 监控
- 添加 ELK 日志收集
- 实现多节点 Kubernetes 集群

## 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| Kubernetes | 1.30 | 容器编排 |
| Keycloak | 24.0.4 | 身份认证 |
| OPA | 0.63.0 | 授权策略 |
| MySQL | 8 | 数据存储 |
| Go | 1.22 | Risk Service |
| Ansible | 2.9+ | 自动化部署 |

## 联系方式

如有问题，请参考：
- QUICK_START.md - 快速开始
- DEPLOYMENT.md - 详细部署指南
- 各组件官方文档

