variable "tags" {
  type        = map(string)
  description = "Tags for RKE2 resources"
  default     = {}
}

variable "cluster_name" {
  type        = string
  description = "Name of cluster being created"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-gov-west-1"
}

variable "vpc_id" {
  type        = string
  description = "ID of a preexisting VPC in which to deploy rke2"
}

variable "subnet_ids" {
  type        = set(string)
  description = "subnets into which RKE2 will be deployed"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of VPC"
  default     = "172.23.0.0/16"
}
