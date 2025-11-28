# 零信任 IAM 毕业设计

基于 Kubernetes 的零信任身份认证与授权系统（Zero-Trust IAM）

## 项目简介

本项目实现了一个完整的零信任安全架构，包含：
- **身份认证**：Keycloak OIDC
- **风险评估**：Go 微服务实时计算风险分数
- **授权决策**：OPA 策略引擎（ABAC）
- **前端演示**：Go SSR Web Portal

## 技术栈

| 组件 | 技术 | 说明 |
|------|------|------|
| 容器编排 | Kubernetes (kubeadm) | 单节点集群 |
| 身份认证 | Keycloak | OIDC/OAuth2 |
| 授权引擎 | OPA | ABAC 策略 |
| 风险评估 | Go 微服务 | 实时风险评分 |
| 前端 | Go (html/template) | SSR 演示门户 |
| 数据库 | MySQL 8 | 持久化存储 |
| 部署自动化 | Ansible | IaC |

## 快速开始

### 方式一：本地演示（推荐快速验证）

**Windows PowerShell:**
```powershell
.\scripts\run-local.ps1
```

**Linux/macOS:**
```bash
bash scripts/run-local.sh
```

自动完成：
1. 构建 risk-service 和 web-portal
2. 启动服务（8080 + 8081）
3. 打开浏览器访问 http://localhost:8081

### 方式二：Kubernetes 部署（完整演示）

**前置条件：**
- Kubernetes 集群（kubeadm 单节点或多节点）
- Ansible 2.9+
- Docker/containerd

**步骤：**

1. **配置目标主机**
   ```bash
   # 编辑 Ansible inventory
   vim ansible/inventory/hosts.ini
   ```

2. **构建镜像**
   ```bash
   docker build -t localhost/risk-service:latest services/risk-service
   docker build -t localhost/web-portal:latest services/web-portal
   ```

3. **部署到 K8s**
   ```bash
   ansible-playbook ansible/playbooks/10-apps.yml
   ```

4. **验证部署**
   ```bash
   kubectl -n security get all
   ```

5. **访问服务**
   - Web Portal: `http://<节点IP>:30081`
   - Keycloak: `http://<节点IP>:30080`

## 项目结构

```
.
├── services/
│   ├── risk-service/       # Go 风险评分微服务
│   └── web-portal/         # Go 前端（SSR + OIDC）
├── ansible/
│   ├── playbooks/          # 部署 playbook
│   ├── group_vars/         # 全局变量
│   └── inventory/          # 主机清单
├── opa/policies/           # OPA 授权策略
├── scripts/                # 辅助脚本
└── docs/                   # 文档
    ├── 需求分析文档.md     # 需求分析
    ├── 系统架构设计.md     # 架构设计
    └── 答辩PPT大纲.md      # 答辩准备

```

## 核心功能

### 1. 风险评估（Risk Service）
- 多因素风险计算：
  - 失败登录次数
  - 地理位置异常
  - 用户角色
  - 访问时间
  - User-Agent 异常
- RESTful API：`POST /score`

### 2. 授权决策（OPA）
- ABAC 策略：基于角色、资源、动作、风险分数
- 策略示例：
  - `read` 操作：允许（风险分数 < 70）
  - `admin` 操作：需要 admin 角色 + 低风险

### 3. OIDC 登录（可选）
- Keycloak 集成
- 登录后自动填充用户信息
- Session 管理（Cookie + 内存）

## 演示流程

1. 访问 Web Portal
2. （可选）使用 Keycloak 登录
3. 填写评估表单：
   - userId, roles, resource, action
   - IP, geo, userAgent, time
   - failedLoginCount
4. 提交后查看：
   - 风险分数（Risk Service）
   - 授权结果（OPA）
   - 风险因素详情

## 文档索引

- **[QUICK_START.md](QUICK_START.md)** - 5 分钟快速开始
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - 详细部署指南
- **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - 项目总结
- **[docs/零信任IAM/](docs/零信任IAM/)** - 详细设计文档

## 常见问题

**Q: OPA 报错怎么办？**
A: 本地演示时 OPA 未启动是正常的，不影响风险评分功能。如需完整演示：
```bash
opa run --server --addr :8181 opa/policies
```

**Q: OIDC 登录按钮不显示？**
A: 需要配置环境变量启用 OIDC（见 `ansible/group_vars/all.yml` 中的 `oidc_*` 变量）

**Q: 如何停止本地服务？**
A: 关闭启动脚本打开的 PowerShell 窗口，或使用 `Ctrl+C`

## 开发

**本地构建：**
```bash
cd services/risk-service
go build -v -o risk-service main.go

cd ../web-portal
go build -v -o web-portal main.go
```

**运行测试：**
```bash
# 测试 risk-service API
curl -X POST http://localhost:8080/score \
  -H "Content-Type: application/json" \
  -d @test-risk.json
```

## 许可证

MIT License（仅供学习使用）
