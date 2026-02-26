# 使用指南

本文档提供零信任 IAM 系统的详细使用说明。

## 目录

- [本地演示](#本地演示)
- [Kubernetes 部署](#kubernetes-部署)
- [OIDC 登录配置](#oidc-登录配置)
- [API 测试](#api-测试)
- [故障排查](#故障排查)

---

## 本地演示

### 快速启动

**Windows:**
```powershell
.\scripts\run-local.ps1
```

**Linux/macOS:**
```bash
chmod +x scripts/run-local.sh
./scripts/run-local.sh
```

### 手动启动

1. **构建服务**
   ```bash
   # risk-service
   cd services/risk-service
   go build -v -o risk-service main.go
   
   # web-portal
   cd ../web-portal
   go build -v -o web-portal main.go
   ```

2. **启动 risk-service**
   ```bash
   cd services/risk-service
   ./risk-service
   # 监听 0.0.0.0:8080
   ```

3. **启动 web-portal**
   ```bash
   cd services/web-portal
   export RISK_SERVICE_URL="http://localhost:8080/score"
   export OPA_URL="http://localhost:8181"
   ./web-portal
   # 监听 :8081
   ```

4. **访问**
   - 浏览器打开：http://localhost:8081
   - 填写表单提交评估

### 启动 OPA（可选）

```bash
# 下载 OPA（如未安装）
# Linux/macOS:
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa

# Windows:
# 从 https://github.com/open-policy-agent/opa/releases 下载 opa_windows_amd64.exe

# 启动 OPA
./opa run --server --addr :8181 opa/policies
```

---

## Kubernetes 部署

### 前置条件

- Kubernetes 集群（1.24+）
- kubectl 配置完成
- Ansible 2.9+
- Docker/containerd

### 部署步骤

#### 1. 配置 Inventory

编辑 `ansible/inventory/hosts.ini`：

```ini
[k8s_master]
192.168.1.100 ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s_nodes]
192.168.1.101 ansible_user=root
192.168.1.102 ansible_user=root
```

#### 2. 配置变量

编辑 `ansible/group_vars/all.yml`：

```yaml
# MySQL
mysql_root_password: "your-secure-password"

# Keycloak
keycloak_admin_password: "your-admin-password"

# OIDC（可选）
oidc_issuer: "http://keycloak:8080/realms/master"
oidc_client_id: "web-portal"
oidc_redirect_url: "http://192.168.1.100:30081/callback"
```

#### 3. 构建镜像

```bash
# 使用脚本
./scripts/build-images.sh localhost latest

# 或手动构建
docker build -t localhost/risk-service:latest services/risk-service
docker build -t localhost/web-portal:latest services/web-portal
```

#### 4. 推送镜像到集群

**方式一：导出/导入（单节点）**
```bash
docker save localhost/risk-service:latest | ssh root@192.168.1.100 'ctr -n k8s.io images import -'
docker save localhost/web-portal:latest | ssh root@192.168.1.100 'ctr -n k8s.io images import -'
```

**方式二：私有仓库**
```bash
# 推送到私有仓库
docker tag localhost/risk-service:latest your-registry.com/risk-service:latest
docker push your-registry.com/risk-service:latest

# 更新 ansible/group_vars/all.yml
risk_service_image: "your-registry.com/risk-service:latest"
```

#### 5. 执行部署

```bash
# 完整部署（包含 K8s 初始化）
ansible-playbook ansible/playbooks/00-all.yml

# 仅部署应用
ansible-playbook ansible/playbooks/10-apps.yml
```

#### 6. 验证部署

```bash
# 查看所有资源
kubectl -n security get all

# 查看 Pod 状态
kubectl -n security get pods

# 查看日志
kubectl -n security logs -f deployment/web-portal
kubectl -n security logs -f deployment/risk-service
```

#### 7. 访问服务

- **Web Portal**: `http://<节点IP>:30081`
- **Keycloak**: `http://<节点IP>:30080`
- **Risk Service**: `http://<节点IP>:30800/score`

---

## OIDC 登录配置

### Keycloak 客户端配置

1. **访问 Keycloak Admin**
   - URL: `http://<节点IP>:30080`
   - 用户名: `admin`
   - 密码: 见 `ansible/group_vars/all.yml` 中的 `keycloak_admin_password`

2. **创建 Client**
   - Realm: `master`（或自定义）
   - Client ID: `web-portal`
   - Client Type: `Public`（或 `Confidential` 需配置 secret）
   - Standard Flow: `Enabled`
   - Valid Redirect URIs: `http://<节点IP>:30081/callback`
   - Web Origins: `http://<节点IP>:30081`

3. **更新 Ansible 变量**

编辑 `ansible/group_vars/all.yml`：

```yaml
oidc_issuer: "http://keycloak:8080/realms/master"
oidc_client_id: "web-portal"
oidc_client_secret: ""  # Public client 留空
oidc_redirect_url: "http://192.168.1.100:30081/callback"
```

4. **重新部署 web-portal**

```bash
ansible-playbook ansible/playbooks/10-apps.yml
```

5. **测试登录**
   - 访问 `http://<节点IP>:30081`
   - 点击"使用 Keycloak 登录"
   - 使用 Keycloak 用户登录
   - 登录成功后返回首页，显示用户信息

---

## API 测试

### Risk Service API

**健康检查:**
```bash
curl http://localhost:8080/health
# 响应: ok
```

**风险评分:**
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
    "time": "2025-11-11T06:00:00Z",
    "failedLoginCount": 0
  }'

# 响应示例:
# {"score":0,"reasons":[]}
```

**高风险场景:**
```bash
curl -X POST http://localhost:8080/score \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "roles": ["user"],
    "resource": "orders",
    "action": "read",
    "ip": "1.2.3.4",
    "userAgent": "curl/7.0",
    "geo": "US",
    "time": "2025-11-11T03:00:00Z",
    "failedLoginCount": 5
  }'

# 响应示例:
# {"score":75,"reasons":["failed_login","geo_mismatch","suspicious_ua","off_hours"]}
```

### OPA API

**授权查询:**
```bash
curl -X POST http://localhost:8181/v1/data/authz/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "roles": ["user"],
      "resource": "orders",
      "action": "read",
      "score": 0
    }
  }'

# 响应示例:
# {"result":true}
```

---

## 故障排查

### 本地服务无法启动

**问题：端口被占用**
```bash
# Windows
netstat -ano | findstr :8080
taskkill /PID <PID> /F

# Linux/macOS
lsof -i :8080
kill -9 <PID>
```

**问题：Go 依赖缺失**
```bash
cd services/web-portal
go mod tidy
go build -v
```

### Kubernetes 部署失败

**问题：Pod 一直 Pending**
```bash
kubectl -n security describe pod <pod-name>
# 检查 Events 部分的错误信息
```

**问题：镜像拉取失败**
```bash
# 检查镜像是否存在
ctr -n k8s.io images ls | grep risk-service

# 重新导入镜像
docker save localhost/risk-service:latest | ssh root@<节点IP> 'ctr -n k8s.io images import -'
```

**问题：Pod CrashLoopBackOff**
```bash
# 查看日志
kubectl -n security logs <pod-name>

# 查看详细信息
kubectl -n security describe pod <pod-name>
```

### OIDC 登录失败

**问题：登录按钮不显示**
- 检查环境变量是否配置：`kubectl -n security get deploy web-portal -o yaml | grep OIDC`
- 确认 `oidc_issuer`、`oidc_client_id`、`oidc_redirect_url` 非空

**问题：Redirect URI 不匹配**
- 检查 Keycloak Client 配置中的 Valid Redirect URIs
- 确保与 `oidc_redirect_url` 一致

**问题：Token 验证失败**
- 检查 Keycloak Issuer URL 是否可访问
- 确认 Client ID 正确

### OPA 授权失败

**问题：OPA 返回 404**
- 检查策略路径：`/v1/data/authz/allow`
- 确认策略文件已加载：`curl http://localhost:8181/v1/policies`

**问题：授权结果不符合预期**
- 检查策略逻辑：`opa/policies/abac.rego`
- 测试策略：`opa test opa/policies`

---

## 性能优化

### 本地开发

- 使用 `go build -race` 检测并发问题
- 使用 `pprof` 分析性能瓶颈

### Kubernetes 生产

- 调整资源限制（CPU/Memory）
- 启用 HPA（Horizontal Pod Autoscaler）
- 配置 Ingress + TLS
- 使用持久化 Session 存储（Redis）

---

## 安全建议

1. **生产环境必须修改默认密码**
   - MySQL root 密码
   - Keycloak admin 密码

2. **启用 HTTPS**
   - 配置 Ingress TLS
   - 使用 cert-manager 自动管理证书

3. **Session 安全**
   - 使用 Redis 替代内存存储
   - 启用 Secure Cookie（HTTPS）
   - 缩短 Session 过期时间

4. **网络隔离**
   - 使用 NetworkPolicy 限制 Pod 间通信
   - 仅暴露必要的 NodePort/Ingress

---

## 更多资源

- [README.md](README.md) - 项目概览
- [QUICK_START.md](QUICK_START.md) - 快速开始
- [docs/INDEX.md](docs/INDEX.md) - 文档总览
- [docs/项目/PROJECT_SUMMARY.md](docs/项目/PROJECT_SUMMARY.md) - 项目总结
- [docs/零信任IAM/](docs/零信任IAM/) - 设计文档

