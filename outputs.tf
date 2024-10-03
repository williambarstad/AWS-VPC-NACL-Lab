output "public-instance-ip" {
  value = aws_instance.public_ec2.public_ip
}

output "private-instance-ip" {
  value = aws_instance.private_ec2.private_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}