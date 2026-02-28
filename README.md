# Zero-Trust IAM System | 零信任身份认证与授权系统

基于 Kubernetes 的零信任身份认证与授权系统

![Go Version](https://img.shields.io/badge/Go-1.22+-00ADD8?style=flat&logo=go)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?style=flat&logo=kubernetes&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## 项目简介

本项目实现了完整的零信任安全架构：

- **身份认证**：Keycloak OIDC/OAuth2
- **风险评估**：Go 微服务实时计算风险分数
- **授权决策**：OPA 策略引擎（ABAC）
- **前端门户**：Go SSR Web Portal

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                 Zero-Trust IAM System                   │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Keycloak   │  │ Risk Service │  │     OPA      │  │
│  │   (AuthN)    │  │   (Scoring)  │  │   (AuthZ)    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
├─────────────────────────────────────────────────────────┤
│                    Web Portal (Go SSR)                  │
├─────────────────────────────────────────────────────────┤
│                 Kubernetes / Docker                     │
└─────────────────────────────────────────────────────────┘
```

## 技术栈

| 组件 | 技术 | 说明 |
|------|------|------|
| 容器编排 | Kubernetes | 集群部署 |
| 身份认证 | Keycloak | OIDC/OAuth2 |
| 授权引擎 | OPA | ABAC 策略 |
| 风险评估 | Go | 实时风险评分微服务 |
| 前端 | Go (html/template) | SSR Web Portal |
| 数据库 | MySQL 8 | 持久化存储 |
| 部署 | Ansible | 基础设施即代码 |

## 快速开始

### 本地运行

**Windows:**
```powershell
.\scripts\run-local.ps1
```

**Linux/macOS:**
```bash
bash scripts/run-local.sh
```

启动后访问：http://localhost:8081

### Kubernetes 部署

```bash
# 1. 配置主机清单
vim ansible/inventory/hosts.ini

# 2. 构建镜像
docker build -t localhost/risk-service:latest services/risk-service
docker build -t localhost/web-portal:latest services/web-portal

# 3. 部署到 K8s
ansible-playbook ansible/playbooks/10-apps.yml

# 4. 验证
kubectl -n security get all
```

**访问地址：**
- Web Portal: `http://<NodeIP>:30081`
- Keycloak: `http://<NodeIP>:30080`

## 项目结构

```
zero-trust-iam/
├── services/
│   ├── risk-service/       # Go 风险评分微服务
│   └── web-portal/         # Go 前端 (SSR + OIDC)
├── ansible/
│   ├── playbooks/          # 部署 Playbook
│   ├── group_vars/         # 全局变量
│   └── inventory/          # 主机清单
├── opa/policies/           # OPA 授权策略
├── keycloak/               # Keycloak 配置
├── scripts/                # 启动脚本
└── docs/                   # 技术文档
```

## 核心功能

### 风险评估服务 (Risk Service)

多因素实时风险评分：
- 失败登录次数
- 地理位置异常检测
- 用户角色权重
- 访问时间分析
- User-Agent 异常检测

**API:** `POST /score`

### 授权决策 (OPA)

基于属性的访问控制 (ABAC)：
- `read` 操作：风险分数 < 70 允许访问
- `admin` 操作：需要 admin 角色 + 低风险分数

### OIDC 集成

- Keycloak 身份提供者
- 自动用户信息填充
- Session 管理

## API 测试

```bash
# 风险评分 API
curl -X POST http://localhost:8080/score \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user1",
    "roles": ["user"],
    "resource": "/api/data",
    "action": "read",
    "ip": "192.168.1.100",
    "geo": "CN",
    "failedLoginCount": 0
  }'
```

## 文档

- [快速开始](QUICK_START.md)
- [使用指南](USAGE.md)
- [API 测试](TEST_API.md)
- [架构设计](docs/系统架构设计.md)
- [需求分析](docs/需求分析文档.md)

## 许可证

MIT License
