variable "cluster_name" {
  type        = string
  description = "Name to prefix to created resources"
}

variable "create" {
  type        = bool
  default     = true
  description = "Toggle creation of buckets"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "bucket_force_destroy" {
  type    = bool
  default = false
}

variable "policy_name" {
  type        = string
  description = "A name for the policy"
}

variable "role_name" {
  type        = string
  description = "A name to give to the role"
}

variable "role_description" {
  type        = string
  description = "A description to place on the created role"
  default     = ""
}

variable "aws_region" {
  type        = string
  description = "aws region in which velero resources exist"
}

variable "identity_provider_arn" {
  type        = string
  description = "Arn of IdentityProvider used for OIDC"
}

variable "oidc_bucket_name" {
  type        = string
  description = "Name of the bucket used to hold the OIDC configuration"
}

variable "velero_k8s_namespace" {
  type        = string
  description = "Name of k8s namespace velero is deployed into"
  default     = "velero"
}

variable "velero_k8s_service_account" {
  type        = string
  description = "Name of service account used by velero pods"
  default     = "default"
}

# variable "kms_key_id" {
#   type        = string
#   description = "KMS key to add grant Velero access to"
# }
