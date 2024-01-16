data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

# 공개 서브넷 생성
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

# 개인 서브넷 생성
resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.my_vpc.cidr_block, 8, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

# 나머지 리소스는 동일하게 유지합니다.

# 공개 라우팅 테이블과 개인 라우팅 테이블 구성
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table" "private_route" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example_nat.id
  }
}

# 라우팅 테이블 연결
resource "aws_route_table_association" "public_association" {
  count          = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_route_table_association" "private_association" {
  count          = length(aws_subnet.private_subnet)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route.id
}

resource "aws_security_group" "my_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = aws_vpc.my_vpc.id
  service_name        = "com.amazonaws.${var.region}.bedrock"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnet[*].id
  security_group_ids  = [aws_security_group.my_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = aws_vpc.my_vpc.id
  service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_subnet[*].id
  security_group_ids  = [aws_security_group.my_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "execute_api" {
  vpc_id             = aws_vpc.my_vpc.id
  service_name       = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.private_subnet[*].id
  security_group_ids = [aws_security_group.my_sg.id]
}

resource "aws_nat_gateway" "example_nat" {
  allocation_id = aws_eip.example_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id # Choose one of your public subnets
}

resource "aws_eip" "example_eip" {}

resource "aws_route_table" "nat_route" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.example_nat.id
  }

  depends_on = [aws_nat_gateway.example_nat]
}
