variable "tags" {
  type        = map(string)
  description = "Tags for RKE2 resources"
  default     = {}
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
