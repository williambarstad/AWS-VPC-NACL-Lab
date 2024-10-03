# main.tf

# VPC and related resources
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env}-vpc-main"
  }
}


# CLOUDWATCH
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


# SUBNETS
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

# Associate Public Subnet with Public Route Table and Internet Gateway
resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# ROUTE TABLES
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

# CUSTOM NACLs
# Create Public NACL
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.main.id
  subnet_ids = [aws_subnet.public_subnet_az1.id]

  tags = {
    Name = "Public NACL"
  }
}

# Public NACL Rules
resource "aws_network_acl_rule" "allow_http_inbound" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "allow_ssh_inbound" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "allow_icmp_inbound" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 120
  protocol       = "icmp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "0.0.0.0/0"
}

# Allow ICMP Echo Request (for ping) from VPC (10.0.0.0/16)
resource "aws_network_acl_rule" "allow_icmp_echo_request" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 130
  protocol       = "icmp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "10.0.0.0/16"
  icmp_type      = 8   # Echo Request (type 8)
  icmp_code      = 0
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
resource "aws_network_acl_rule" "allow_internal_traffic_inbound" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "10.0.0.0/16"
  from_port      = 0
  to_port        = 65535
}

resource "aws_network_acl_rule" "allow_internal_traffic_outbound" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  egress         = true
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

# Allow ICMP Echo Reply from Private Subnet to Public Subnet
resource "aws_network_acl_rule" "allow_icmp_echo_reply" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 110
  protocol       = "icmp"
  rule_action    = "allow"
  egress         = false
  cidr_block     = "10.0.0.0/16"  # VPC CIDR for internal communication
  icmp_type      = 0   # Echo Reply (type 0)
  icmp_code      = 0
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


# SECURITY GROUPS
# Public Security Group
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id
  name   = "public_sg"
  description = "Allow SSH and HTTP traffic for Public EC2"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "PublicEC2SG" }
}

# Private Security Group
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id
  name   = "private_sg"
  description = "Allow SSH from Public EC2 and ICMP for Private EC2"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.public_sg.id] # Allow SSH from Public EC2 SG
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"] # Allow ICMP within VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "PrivateEC2SG" }
}


# EC2 INSTANCES
# One for each subnet. The public instance will be used to test the private instance.
# Public EC2 Instance (with Apache and a web browser)
resource "aws_instance" "public_ec2" {
  ami                         = var.ami
  instance_type               = var.instance_type
  iam_instance_profile        = var.wjb_ami_instance_profile
  subnet_id                   = aws_subnet.public_subnet_az1.id
  security_groups             = [aws_security_group.public_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  tags = {
    Name = "${var.env}-PublicEC2"
  }

  user_data = <<-EOF
    #!/bin/bash     
    sudo su     
    yum update -y       
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    yum install httpd -y    
    echo "<html><h1>Welcome to WJB Server </h1><html>" >> /var/www/html/index.html     
    systemctl start httpd           
    systemctl enable httpd
  EOF
}

# Private EC2 Instance (no public IP, internal only)
resource "aws_instance" "private_ec2" {
  ami                         = var.ami
  instance_type               = var.instance_type
  iam_instance_profile        = var.wjb_ami_instance_profile
  subnet_id                   = aws_subnet.private_subnet_az1.id
  security_groups             = [aws_security_group.private_sg.id]
  associate_public_ip_address = false
  key_name                    = var.key_name

  tags = {
    Name = "${var.env}-PrivateEC2"
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF
}

