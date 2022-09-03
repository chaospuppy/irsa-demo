data "aws_canonical_user_id" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "openid_configuration" {
  bucket = var.oidc_bucket_name
  tags   = var.oidc_bucket_tags
}

resource "aws_s3_bucket_acl" "openid_configuration" {
  bucket = aws_s3_bucket.openid_configuration.id
  access_control_policy {
    grant {
      grantee {
        id   = data.aws_canonical_user_id.current.id
        type = "CanonicalUser"
      }
      permission = "FULL_CONTROL"
    }

    owner {
      id = data.aws_canonical_user_id.current.id
    }
  }
}

resource "aws_s3_bucket_policy" "openid_configuration" {
  bucket = aws_s3_bucket.openid_configuration.id
  policy = templatefile("oidc_bucket_policy.tftpl", {
    bucket_arn = aws_s3_bucket.openid_configuration.arn
    account_id = data.aws_caller_identity.current.account_id
  })
}
