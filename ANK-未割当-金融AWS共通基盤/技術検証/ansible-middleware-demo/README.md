# Ansible + Terraform ミドルウェア構築デモ

## 概要

Terraform でインフラを構築し、Ansible でミドルウェアを設定するハイブリッド構成のデモプロジェクトです。

```
┌─────────────────────────────────────────────────────────────────┐
│                    Infrastructure as Code                        │
│                                                                   │
│  ┌─────────────────┐         ┌─────────────────┐                │
│  │   Terraform     │         │    Ansible      │                │
│  │                 │         │                 │                │
│  │ ・VPC/Subnet    │ ──────> │ ・Nginx         │                │
│  │ ・EC2           │  SSH    │ ・Docker        │                │
│  │ ・Security Group│         │ ・Node Exporter │                │
│  │ ・ALB           │         │ ・Fluentd       │                │
│  └─────────────────┘         └─────────────────┘                │
│                                                                   │
│        インフラ層                    ミドルウェア層               │
└─────────────────────────────────────────────────────────────────┘
```

## なぜ Terraform + Ansible の併用か？

| ツール | 得意分野 | 用途 |
|--------|---------|------|
| **Terraform** | インフラのプロビジョニング | AWS リソース（EC2, VPC, RDS等）の作成・管理 |
| **Ansible** | サーバー構成管理 | OS設定、パッケージ、ミドルウェアの設定 |

**併用するメリット**:
- Terraform: インフラの冪等性、状態管理、依存関係の自動解決
- Ansible: エージェントレス、豊富なモジュール、設定の柔軟性

---

## ディレクトリ構成

```
ansible-middleware-demo/
├── README.md
├── terraform/                    # インフラ構築
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── environments/
│       ├── dev.tfvars
│       └── prod.tfvars
│
├── ansible/                      # ミドルウェア設定
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml             # 静的インベントリ
│   │   └── aws_ec2.yml           # 動的インベントリ（AWS）
│   │
│   ├── playbooks/
│   │   ├── site.yml              # メインプレイブック
│   │   ├── webserver.yml         # Webサーバー設定
│   │   ├── docker.yml            # Docker設定
│   │   └── monitoring.yml        # 監視エージェント設定
│   │
│   ├── roles/
│   │   ├── common/               # 共通設定
│   │   ├── nginx/                # Nginx設定
│   │   ├── docker/               # Docker設定
│   │   ├── node_exporter/        # Prometheus Node Exporter
│   │   └── fluentd/              # ログ収集
│   │
│   └── group_vars/
│       ├── all.yml
│       ├── webservers.yml
│       └── appservers.yml
│
└── scripts/
    ├── deploy.sh                 # 統合デプロイスクリプト
    └── destroy.sh                # クリーンアップ
```

---

## クイックスタート

### 前提条件

- Terraform >= 1.0
- Ansible >= 2.14
- AWS CLI（認証情報設定済み）
- SSH キーペア

### 1. インフラ構築（Terraform）

```bash
cd terraform

# 初期化
terraform init

# プラン確認
terraform plan -var-file=environments/dev.tfvars

# 適用
terraform apply -var-file=environments/dev.tfvars

# 出力確認（Ansible用のホスト情報）
terraform output -json > ../ansible/inventory/terraform_outputs.json
```

### 2. ミドルウェア設定（Ansible）

```bash
cd ansible

# 接続テスト
ansible all -m ping -i inventory/hosts.yml

# ミドルウェア設定実行
ansible-playbook playbooks/site.yml -i inventory/hosts.yml
```

### 3. 統合デプロイ（スクリプト）

```bash
./scripts/deploy.sh dev
```

---

## Terraform 設計

### リソース構成

```hcl
# 作成されるリソース
- VPC (10.0.0.0/16)
  ├── Public Subnet (10.0.1.0/24, 10.0.2.0/24)
  ├── Private Subnet (10.0.11.0/24, 10.0.12.0/24)
  ├── Internet Gateway
  └── NAT Gateway

- EC2 Instances
  ├── Web Server x 2 (Public Subnet)
  └── App Server x 2 (Private Subnet)

- Application Load Balancer
  └── Target Group (Web Servers)

- Security Groups
  ├── ALB-SG (80, 443)
  ├── Web-SG (80, 443, 22)
  └── App-SG (8000, 22)
```

### Terraform → Ansible 連携

Terraform の出力を Ansible インベントリに渡す：

```hcl
# outputs.tf
output "web_server_ips" {
  value = aws_instance.web[*].public_ip
}

output "app_server_ips" {
  value = aws_instance.app[*].private_ip
}

output "ansible_inventory" {
  value = templatefile("${path.module}/templates/inventory.tpl", {
    web_servers = aws_instance.web[*].public_ip
    app_servers = aws_instance.app[*].private_ip
  })
}
```

---

## Ansible 設計

### ロール構成

| ロール | 説明 | 対象 |
|--------|------|------|
| `common` | 共通設定（タイムゾーン、パッケージ、ユーザー） | 全サーバー |
| `nginx` | Nginx インストール・設定 | Web サーバー |
| `docker` | Docker CE インストール・設定 | App サーバー |
| `node_exporter` | Prometheus Node Exporter | 全サーバー |
| `fluentd` | ログ収集エージェント | 全サーバー |

### プレイブック構成

```yaml
# site.yml - メインプレイブック
---
- name: Apply common configuration
  hosts: all
  become: yes
  roles:
    - common
    - node_exporter
    - fluentd

- name: Configure web servers
  hosts: webservers
  become: yes
  roles:
    - nginx

- name: Configure app servers
  hosts: appservers
  become: yes
  roles:
    - docker
```

### 動的インベントリ（AWS EC2）

```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions:
  - ap-northeast-1

filters:
  tag:Environment: "{{ lookup('env', 'ENV') | default('dev') }}"
  instance-state-name: running

keyed_groups:
  - key: tags.Role
    prefix: role
  - key: tags.Environment
    prefix: env

compose:
  ansible_host: public_ip_address
```

---

## ロール詳細

### common ロール

```yaml
# roles/common/tasks/main.yml
---
- name: Set timezone to Asia/Tokyo
  timezone:
    name: Asia/Tokyo

- name: Update package cache
  apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Install common packages
  apt:
    name:
      - vim
      - curl
      - wget
      - htop
      - net-tools
      - unzip
    state: present

- name: Configure sysctl parameters
  sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    state: present
    reload: yes
  loop:
    - { name: 'net.core.somaxconn', value: '65535' }
    - { name: 'vm.swappiness', value: '10' }
```

### nginx ロール

```yaml
# roles/nginx/tasks/main.yml
---
- name: Install Nginx
  apt:
    name: nginx
    state: present

- name: Copy Nginx configuration
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx

- name: Copy site configuration
  template:
    src: default.conf.j2
    dest: /etc/nginx/sites-available/default
  notify: Reload Nginx

- name: Ensure Nginx is running
  service:
    name: nginx
    state: started
    enabled: yes
```

### docker ロール

```yaml
# roles/docker/tasks/main.yml
---
- name: Install prerequisites
  apt:
    name:
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
    state: present

- name: Add Docker GPG key
  apt_key:
    url: https://download.docker.com/linux/ubuntu/gpg
    state: present

- name: Add Docker repository
  apt_repository:
    repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
    state: present

- name: Install Docker CE
  apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-compose-plugin
    state: present
    update_cache: yes

- name: Add user to docker group
  user:
    name: "{{ ansible_user }}"
    groups: docker
    append: yes

- name: Ensure Docker is running
  service:
    name: docker
    state: started
    enabled: yes

- name: Configure Docker daemon
  template:
    src: daemon.json.j2
    dest: /etc/docker/daemon.json
  notify: Restart Docker
```

### node_exporter ロール

```yaml
# roles/node_exporter/tasks/main.yml
---
- name: Create node_exporter user
  user:
    name: node_exporter
    system: yes
    shell: /sbin/nologin

- name: Download node_exporter
  get_url:
    url: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz"
    dest: /tmp/node_exporter.tar.gz

- name: Extract node_exporter
  unarchive:
    src: /tmp/node_exporter.tar.gz
    dest: /usr/local/bin
    remote_src: yes
    extra_opts:
      - --strip-components=1
      - --wildcards
      - "*/node_exporter"

- name: Create systemd service
  template:
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service
  notify:
    - Reload systemd
    - Restart node_exporter

- name: Ensure node_exporter is running
  service:
    name: node_exporter
    state: started
    enabled: yes
```

---

## 変数管理

### group_vars/all.yml

```yaml
---
# 共通設定
timezone: Asia/Tokyo
ntp_servers:
  - ntp.nict.jp
  - ntp1.jst.mfeed.ad.jp

# SSH設定
ssh_port: 22
ssh_allow_password: no

# 監視設定
node_exporter_version: "1.7.0"
node_exporter_port: 9100

# ログ設定
fluentd_log_path: /var/log
fluentd_output_host: "{{ lookup('env', 'FLUENTD_OUTPUT_HOST') | default('localhost') }}"
```

### group_vars/webservers.yml

```yaml
---
# Nginx設定
nginx_worker_processes: auto
nginx_worker_connections: 4096
nginx_keepalive_timeout: 65

# サイト設定
nginx_server_name: "{{ inventory_hostname }}"
nginx_root: /var/www/html
nginx_index: index.html

# アップストリーム（App サーバー）
nginx_upstream_servers: "{{ groups['appservers'] | map('regex_replace', '$', ':8000') | list }}"
```

---

## デプロイスクリプト

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

ENV=${1:-dev}
echo "=== Deploying to ${ENV} environment ==="

# 1. Terraform でインフラ構築
echo ">>> Running Terraform..."
cd terraform
terraform init
terraform apply -var-file=environments/${ENV}.tfvars -auto-approve

# 2. Terraform 出力を取得
echo ">>> Getting Terraform outputs..."
terraform output -json > ../ansible/inventory/terraform_outputs.json

# 3. 動的インベントリ更新待ち
echo ">>> Waiting for instances to be ready..."
sleep 60

# 4. Ansible でミドルウェア設定
echo ">>> Running Ansible..."
cd ../ansible
export ENV=${ENV}
ansible-playbook playbooks/site.yml -i inventory/aws_ec2.yml

echo "=== Deployment complete ==="
```

---

## ローカルテスト（Vagrant）

AWS を使わずにローカルでテストする場合：

```ruby
# Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # Web Server
  config.vm.define "web1" do |web|
    web.vm.hostname = "web1"
    web.vm.network "private_network", ip: "192.168.56.11"
  end

  # App Server
  config.vm.define "app1" do |app|
    app.vm.hostname = "app1"
    app.vm.network "private_network", ip: "192.168.56.21"
  end

  config.vm.provision "ansible" do |ansible|
    ansible.playbook = "ansible/playbooks/site.yml"
    ansible.groups = {
      "webservers" => ["web1"],
      "appservers" => ["app1"]
    }
  end
end
```

```bash
# ローカルテスト実行
vagrant up
vagrant provision
```

---

## ベストプラクティス

### Terraform

1. **状態管理**: S3 + DynamoDB でリモートステート
2. **変数分離**: 環境ごとに tfvars ファイル
3. **モジュール化**: 再利用可能なモジュール設計
4. **タグ付け**: すべてのリソースに Environment, Role タグ

### Ansible

1. **冪等性**: 何度実行しても同じ結果
2. **ロール分離**: 単一責任の原則
3. **変数の階層**: group_vars > host_vars > playbook vars
4. **ハンドラー活用**: 変更時のみサービス再起動
5. **Vault**: 機密情報の暗号化

### 連携

1. **Terraform → Ansible**: 動的インベントリ or 出力ファイル
2. **タグベース**: EC2 タグでグループ分け
3. **Provisioner回避**: Ansible は Terraform 外で実行

---

## 関連ドキュメント

- [IaC運用ガイドライン](../../参画用/運用ドキュメント/03_IaC運用ガイドライン.md)
- [コンテナ運用マニュアル](../../参画用/運用ドキュメント/04_コンテナ運用マニュアル.md)
- [SRE監視設計書](../../参画用/運用ドキュメント/05_SRE監視設計書.md)
