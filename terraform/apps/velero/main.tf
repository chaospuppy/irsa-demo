locals {
  assume-role-variables = {
    aws_region               = var.aws_region
    identity_provider_arn    = var.identity_provider_arn
    identity_provider_bucket = var.oidc_bucket_name
    velero_namespace         = var.velero_k8s_namespace
    velero_service_account   = var.velero_k8s_service_account
  }
  iam-policy-variables = {
    cluster_name = var.cluster_name
  }
}

resource "aws_kms_key" "velero" {
  description = "KSM key used for Velero decrypt/encrypt and data key generation actions"
  key_usage   = "ENCRYPT_DECRYPT"
  tags        = var.tags
}

module "velero_bucket" {
  create_bucket = var.create
  source        = "terraform-aws-modules/s3-bucket/aws"
  bucket        = "${var.cluster_name}-velero-backups"
  acl           = "private"
  force_destroy = var.bucket_force_destroy
  tags          = var.tags

  versioning = {
    enabled = false
  }
}

resource "aws_iam_role" "velero" {
  name               = var.role_name
  description        = var.role_description
  assume_role_policy = templatefile("velero-assume-role-policy.tftpl", local.assume-role-variables)
  tags               = var.tags
}

resource "aws_iam_policy" "velero" {
  name = var.policy_name
  policy = templatefile("velero-iam-policy.tftpl", merge(
    local.iam-policy-variables,
    {
      kms_key_arn = aws_kms_key.velero.arn
    }
  ))
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "velero" {
  role       = var.role_name
  policy_arn = aws_iam_policy.velero.arn
}

resource "aws_kms_grant" "velero_grant" {
  grantee_principal = aws_iam_role.velero.arn
  key_id            = aws_kms_key.velero.id
  operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]

  //  Revoke instead of retire on delete, this is a little misleading
  retire_on_delete = false
}

