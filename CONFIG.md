# 🔐 配置指南

## 安全配置说明

在部署前，请务必修改以下配置文件中的默认密码和密钥！

### 1. Ansible 部署配置

文件：`ansible/group_vars/all.yml`

```yaml
# 修改这些值为你自己的密码
mysql_root_password: "你的MySQL密码"
keycloak_admin_password: "你的Keycloak管理员密码"
```

### 2. OIDC 配置（可选）

如果需要启用Keycloak OIDC登录，在 `ansible/group_vars/all.yml` 中配置：

```yaml
oidc_issuer: "http://你的IP:30080/realms/master"
oidc_client_id: "web-portal"
oidc_client_secret: "从Keycloak获取"
oidc_redirect_url: "http://你的IP:30081/callback"
```

### 3. 脚本配置

文件：`scripts/deploy-all-services.sh`

- 同样需要修改 `MYSQL_ROOT_PASSWORD` 和 `KEYCLOAK_ADMIN_PASSWORD`

## ⚠️ 安全提示

- **切勿在生产环境使用默认密码！**
- 建议使用环境变量或密钥管理工具（如 HashiCorp Vault）
- 不要将真实密码提交到公开仓库

## 示例环境变量方式

```bash
export MYSQL_ROOT_PASSWORD="你的密码"
export KEYCLOAK_ADMIN_PASSWORD="你的密码"

# 在Ansible中使用
ansible-playbook playbooks/10-apps.yml \
  -e mysql_root_password=$MYSQL_ROOT_PASSWORD \
  -e keycloak_admin_password=$KEYCLOAK_ADMIN_PASSWORD
```
