#!/bin/bash
# =============================================================================
# Deploy Script - Terraform + Ansible 統合デプロイ
# =============================================================================

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================="
echo "Deploying to ${ENV} environment"
echo "============================================="

# 1. Terraform でインフラ構築
echo ""
echo ">>> [1/4] Running Terraform..."
cd "${PROJECT_DIR}/terraform"

terraform init -upgrade
terraform plan -var-file="environments/${ENV}.tfvars" -out=tfplan
terraform apply tfplan

# 2. Terraform 出力を取得
echo ""
echo ">>> [2/4] Generating Ansible inventory..."
terraform output -json > "${PROJECT_DIR}/ansible/inventory/terraform_outputs.json"

# 3. インスタンス起動待ち
echo ""
echo ">>> [3/4] Waiting for instances to be ready..."
echo "Waiting 60 seconds for instances to initialize..."
sleep 60

# 4. Ansible でミドルウェア設定
echo ""
echo ">>> [4/4] Running Ansible..."
cd "${PROJECT_DIR}/ansible"

export ENV="${ENV}"

# 接続テスト
echo "Testing SSH connectivity..."
ansible all -m ping -i inventory/hosts.yml || {
    echo "SSH connection failed. Retrying in 30 seconds..."
    sleep 30
    ansible all -m ping -i inventory/hosts.yml
}

# プレイブック実行
ansible-playbook playbooks/site.yml -i inventory/hosts.yml

echo ""
echo "============================================="
echo "Deployment complete!"
echo "============================================="

# 出力情報表示
cd "${PROJECT_DIR}/terraform"
echo ""
echo "ALB DNS Name:"
terraform output alb_dns_name

echo ""
echo "Web Server IPs:"
terraform output web_server_public_ips
