variable "oidc_bucket_name" {
  type        = string
  description = "Name for the bucket used to host the openid configuration and JWKS"
  default     = "irsa-demo-bucket"
}

variable "oidc_bucket_tags" {
  type        = map(string)
  description = "Map of tags to apply to the OIDC bucket"
  default = {
    "component" = "oidc"
    "project"   = "irsa-demo"
  }
}
