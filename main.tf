# main.tf

# VPC and related resources
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env}-main"
  }
}

# CloudWatch log group for VPC flow logs
resource "aws_cloudwatch_log_group" "flow_logs_group" {
  name              = "${var.env}-flow-logs-group"
  retention_in_days = 14  # Set the retention as needed
}

# IAM role for VPC flow logs
resource "aws_iam_role" "flow_logs_role" {
  name = "${var.env}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CloudWatch Logs
resource "aws_iam_role_policy" "flow_logs_policy" {
  name   = "${var.env}-flow-logs-policy"
  role   = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.flow_logs_group.arn}:*"
      }
    ]
  })
}

# VPC flow logs sending to CloudWatch Logs
resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.flow_logs_group.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"  # Options: ACCEPT, REJECT, or ALL
  vpc_id               = aws_vpc.main.id

  iam_role_arn = aws_iam_role.flow_logs_role.arn
}

# Subnets
# Public Subnet AZ1
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_az1
  availability_zone       = var.azone1
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-${var.azone1}"
  }
}

# Private Subnet AZ1
resource "aws_subnet" "private_subnet_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_az1
  availability_zone = var.azone1
  tags = {
    Name = "${var.env}-private-${var.azone1}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-igw"
  }
}

# Route Tables
# Route Table for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-public"
  }
}

resource "aws_route_table_association" "public_azone1" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_azone1" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_rt.id
}

# Create Public NACL
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.main.id
  subnet_ids = [aws_subnet.public_subnet_az1.id]

  tags = {
    Name = "Public NACL"
  }
}

# Public NACL Rules
resource "aws_network_acl_rule" "allow_all_inbound_public" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

resource "aws_network_acl_rule" "allow_all_outbound_public" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

# Create Private NACL
resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_subnet_az1.id]

  tags = {
    Name = "Private NACL"
  }
}

# Private NACL Rules (allow specific traffic)
resource "aws_network_acl_rule" "allow_inbound_private" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "10.0.0.0/16"  # Change to your internal CIDR block
  from_port      = 0
  to_port        = 65535
}

resource "aws_network_acl_rule" "allow_outbound_private" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

# Associate Public NACL with Public Route Table
resource "aws_route_table_association" "public_nacl_association" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate Private NACL with Private Route Table
resource "aws_route_table_association" "private_nacl_association" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_rt.id
}

