variable "instance_profile" {
  description = "The name of the instance profile"
  default     = "williambarstad"
}

variable "account_id" {
  description = "The AWS account ID"
  default     = "602401143452"
}

variable "env" {
  description = "The environment name (e.g., dev, prod)"
  default     = "dev"
}

variable "region" {
  description = "The AWS region to deploy resources"
  default     = "us-west-2"
}

variable "azone1" {
  description = "The first availability zone"
  default     = "us-west-2a"
}

variable "azone2" {
  description = "The second availability zone"
  default     = "us-west-2b"
}

variable "ami_name" {
  description = "The name of the AMI to use for the EKS nodes"
  default     = "al2023-ami-2023.5.20240903.0-kernel-6.1-x86_64"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

# Subnet variables
variable "public_subnet_cidr_az1" {
  description = "CIDR block for the public subnet in availability zone 1"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_az1" {
  description = "CIDR block for the private subnet in availability zone 1"
  default     = "10.0.2.0/24"
}

variable "public_subnet_cidr_az2" {
  description = "CIDR block for the public subnet in availability zone 2"
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr_az2" {
  description = "CIDR block for the private subnet in availability zone 2"
  default     = "10.0.4.0/24"
}

variable "key_name" {
  description = "The name of the SSH key to use for the EKS nodes"
  default     = "wjb-key-0001"
}