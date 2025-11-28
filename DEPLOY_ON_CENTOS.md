# CentOS Stream 9 部署指南

本指南将帮助你在 CentOS Stream 9 服务器上部署零信任 IAM 系统。

## 1. 准备工作

确保你已经通过 SSH 连接到服务器（如你当前的 `192.168.76.129`）。

## 2. 上传代码

你需要将项目代码上传到服务器。你可以使用 `scp` 或 `rsync`，或者如果你的代码在 Git 上，直接 clone。

假设你已经将代码上传到 `/root/project` 或类似目录。

## 3. 一键部署

我们为你准备了一个一键部署脚本，它会自动处理：
1. 安装依赖 (Ansible, Podman, Git)
2. 初始化系统 (关闭 Swap, 设置 SELinux, 开放防火墙)
3. 安装 Kubernetes (Kubeadm, Containerd)
4. 构建并导入 Docker 镜像
5. 部署所有应用

**执行命令：**

```bash
# 进入项目目录
cd /path/to/project

# 添加执行权限
chmod +x scripts/deploy_on_centos9.sh

# 运行部署脚本
./scripts/deploy_on_centos9.sh
```

## 4. 验证部署

脚本执行完成后，你可以使用以下命令检查状态：

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get pods -n security
```

## 5. 访问系统

- **Web Portal**: `http://192.168.76.129:30081`
- **Keycloak**: `http://192.168.76.129:30080`

## 常见问题

- **镜像构建失败**：脚本会自动设置 `GOPROXY=https://goproxy.cn`，确保服务器能访问公网。
- **K8s 启动失败**：检查 `journalctl -u kubelet` 查看日志。
