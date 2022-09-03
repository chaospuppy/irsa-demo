variable "oidc_configuration_url" {
  type        = string
  description = "URL (protocol included) where the ./well-known/oidc-configuration can be found"
}

variable "oidc_client_id_list" {
  type        = set(string)
  description = "List of valid client ids (audiences) that will use this provider"
  default     = ["irsa.demo"]
}

variable "oidc_url_thumbprint_list" {
  type        = set(string)
  description = "List of thumprints identifying the OIDC endpoint.  Default is the thumprint for the us-gov-west-1 S3 endpoint."
  default = [
    "CD3E919FBBEA084F9140937ED3555066E20CBB28"
  ]
}
