variable "cluster_name" {
  default = "kahiro-playground"
}
variable "domain" {
  description = "The domain name of the cluster."
  default     = null
}
variable "aws_region" {
  description = "The region to provision AWS resources in."
  default     = "ap-northeast-1"
}
variable "aws_vpc_cidr_block" {
  description = "The CIDR block to use for the AWS VPC."
  default     = "10.0.0.0/16"
}
variable "aws_vpc_cidr_public_subnets" {
  description = "The public subnet CIDR blocks"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}
variable "aws_vpc_cidr_private_subnets" {
  description = "The private subnet CIDR blocks"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "aws_repo" {
  default = "kahiro-eks-blueprint"
}

variable "env" {
  default = "dev"
}

variable "organization" {
  default = "kahiro-sandbox"
}

variable "workspace" {
  default = "iam"
}
