output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value       = aws_subnet.private_subnet_az1.id
  description = "Private subnet IDs used for the EKS cluster."
}
