resource "aws_iam_openid_connect_provider" "irsa_demo" {
  url             = var.oidc_configuration_url
  client_id_list  = var.oidc_client_id_list
  thumbprint_list = var.oidc_url_thumbprint_list
}
