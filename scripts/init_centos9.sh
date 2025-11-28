#!/usr/bin/env bash
set -euo pipefail

# 基础包安装
if command -v dnf >/dev/null 2>&1; then
  pkg=dnf
else
  pkg=yum
fi

echo "Installing base packages..."
sudo $pkg -y install epel-release || true
sudo $pkg -y install python3 python3-pip git curl tar unzip jq yum-utils

# 禁用 swap（Kubernetes 要求）
echo "Disabling swap..."
if swapon --show | grep -q "."; then
  sudo swapoff -a
fi
sudo sed -ri '/\sswap\s/s/^/#/' /etc/fstab || true

# SELinux 设置为 permissive
echo "Setting SELinux to permissive..."
if command -v setenforce >/dev/null 2>&1; then
  sudo setenforce 0 || true
fi
sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config || true

# 开放防火墙端口
echo "Opening firewall ports..."
if systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --permanent --add-service=ssh || true
  sudo firewall-cmd --permanent --add-port=6443/tcp || true  # Kubernetes API
  sudo firewall-cmd --permanent --add-port=8080/tcp || true  # Keycloak, Risk Service
  sudo firewall-cmd --permanent --add-port=8181/tcp || true  # OPA
  sudo firewall-cmd --permanent --add-port=3306/tcp || true  # MySQL
  sudo firewall-cmd --reload || true
fi

echo "✓ CentOS 9 initialization completed"
echo "Next: Run Ansible playbook from control machine"
