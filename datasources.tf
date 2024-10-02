data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["${var.ami_name}"]
  }
}