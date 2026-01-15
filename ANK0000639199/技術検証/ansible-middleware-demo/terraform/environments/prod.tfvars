# =============================================================================
# Production Environment Variables
# =============================================================================

environment = "prod"

# Network
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
enable_nat_gateway   = true

# EC2
key_name           = "your-key-pair"  # 実際のキーペア名に変更
web_instance_count = 2
web_instance_type  = "t3.small"
app_instance_count = 2
app_instance_type  = "t3.medium"

# SSH Access - 踏み台サーバーまたはVPN経由のみ
ssh_allowed_cidrs = ["10.0.0.0/8"]
