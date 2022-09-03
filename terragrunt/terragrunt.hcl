locals {
  cluster_name = "irsa-demo"
  aws_region = "us-gov-west-1"
  oidc_bucket_name = "${local.cluster_name}-bucket"
}

inputs = {
  # Generic globals
  aws_region = local.aws_region
  cluster_name = local.cluster_name
  tags = {
    "owner" = "Tim Seagren"
    "supports" = "IRSA Demo"
  }

  # Identity Provider high in the directory tree because it's frequently referenced by nested modules
  oidc_bucket_name = local.oidc_bucket_name
  oidc_configuration_url = "https://s3-${local.aws_region}.amazonaws.com/${local.oidc_bucket_name}"
}

remote_state {
  backend = "s3"

  config = {
    bucket         = "${local.cluster_name}-tf"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "${local.aws_region}"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
}
terraform {
  backend "s3" {}
}
EOF
}
