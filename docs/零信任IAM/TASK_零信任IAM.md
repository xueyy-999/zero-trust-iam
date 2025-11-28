# 零信任 IAM 毕设 - 核心功能清单

## 已实现的功能

### 1. 基础设施
- [x] Kubernetes 单节点集群（kubeadm）
- [x] Ansible 自动化部署
- [x] MySQL 数据库（持久化存储）

### 2. 身份认证
- [x] Keycloak OIDC 服务
- [x] 管理员账户配置

### 3. 授权与策略
- [x] OPA 策略引擎
- [x] ABAC 授权规则（abac.rego）

### 4. 风险评估
- [x] Risk Service 风险评分服务
- [x] 规则：失败登录次数、地理位置、时间段、缺失 User-Agent

## 部署流程

1. 更新 `ansible/inventory/hosts.ini` - 改为你的 CentOS IP
2. 更新 `ansible/group_vars/all.yml` - 改密码和镜像
3. 运行 `ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00-all.yml`
4. 验证：`kubectl -n security get all`
