output "identity_provider_arn" {
  value = aws_iam_openid_connect_provider.irsa_demo.arn
}
