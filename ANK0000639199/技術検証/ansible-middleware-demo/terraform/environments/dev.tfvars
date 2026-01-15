# =============================================================================
# Development Environment Variables
# =============================================================================

environment = "dev"

# Network
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
enable_nat_gateway   = false  # コスト削減のため無効

# EC2
key_name           = "your-key-pair"  # 実際のキーペア名に変更
web_instance_count = 1
web_instance_type  = "t3.micro"
app_instance_count = 1
app_instance_type  = "t3.small"

# SSH Access
ssh_allowed_cidrs = ["0.0.0.0/0"]  # 開発用：本番では制限すること
