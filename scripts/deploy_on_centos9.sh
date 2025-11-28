#!/bin/bash
set -e

echo "=================================================="
echo "   Zero Trust IAM - CentOS Stream 9 Deployment    "
echo "=================================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# 1. Install Dependencies
echo "[1/5] Installing Dependencies (Ansible, Git, Podman)..."
dnf install -y epel-release
dnf install -y ansible git podman

# 2. Prepare Ansible Inventory (Localhost)
echo "[2/5] Preparing Ansible Inventory..."
mkdir -p ansible/inventory
cat > ansible/inventory/local.ini <<EOF
[k8s_master]
localhost ansible_connection=local

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

# 3. Install Kubernetes Cluster
echo "[3/5] Installing Kubernetes Cluster..."
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook -i ansible/inventory/local.ini ansible/playbooks/01-k8s.yml

echo "Waiting for node to be ready..."
sleep 10
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes

# 4. Build and Import Images
echo "[4/5] Building and Importing Images..."

# Build Risk Service
echo "Building risk-service..."
podman build -t localhost/risk-service:latest services/risk-service

# Build Web Portal
echo "Building web-portal..."
podman build -t localhost/web-portal:latest services/web-portal

echo "Importing images to Kubernetes (containerd)..."
# Export from Podman and Import to Containerd (k8s.io namespace)
podman save -o risk-service.tar localhost/risk-service:latest
ctr -n k8s.io images import risk-service.tar
rm risk-service.tar

podman save -o web-portal.tar localhost/web-portal:latest
ctr -n k8s.io images import web-portal.tar
rm web-portal.tar

# 5. Deploy Applications
echo "[5/5] Deploying Applications..."
ansible-playbook -i ansible/inventory/local.ini ansible/playbooks/10-apps.yml

echo "=================================================="
echo "   Deployment Complete!                           "
echo "=================================================="
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "Access the Web Portal at: http://${IP_ADDR}:30081"
echo "Keycloak: http://${IP_ADDR}:30080"
echo "Risk Service: http://${IP_ADDR}:30082 (if NodePort enabled)"
