resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.name })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.name}-public-${count.index}" })
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = element(var.availability_zones, count.index)
  tags              = merge(var.tags, { Name = "${var.name}-private-${count.index}" })
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnets)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 多 NAT モード: 1 private subnet ごとに 1 つの route table を作る (AZ-local routing)。
#   private_subnets[i] → public_subnets[i] にある NAT[i] (同じ AZ)
# variables.tf 側 validation で multi-NAT (single_nat_gateway=false) 時は
# length(private_subnets) == length(public_subnets) を強制しているため、
# i は両 list で有効な index となり cross-AZ 経路は発生しない。
# single_nat_gateway=true (コスト最適化モード) では 1 つの route table を全 private subnet で共有。
#
# 防御: enable_nat_gateway=true + public_subnets=[] / 数不一致は variables.tf 側で reject される。
# 万が一 validation を回避されても max(1, ...) で modulo の div-by-zero を防ぐ (route block 自体は不生成)。
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnets)) : 1
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    # NAT が 0 個なら route block を生成しない (validation で本来到達しない経路)。
    for_each = var.enable_nat_gateway && length(aws_nat_gateway.this) > 0 ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      # multi-NAT モード: AZ-local (i ↔ i) なので modulo は冗長だが defense-in-depth で残す。
      # single-NAT モード: 全 private subnet が aws_nat_gateway.this[0] を共有 (this resource は count=1)。
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index % max(1, length(aws_nat_gateway.this))].id
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-private-rt-${count.index}" })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.enable_nat_gateway && !var.single_nat_gateway ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}
