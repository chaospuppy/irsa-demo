include "root" {
  path = find_in_parent_folders()
  expose = true
}

terraform {
  source = "../../..//terraform/apps/velero/"
}

dependency "identity_provider" {
  config_path = "../..//identity-provider/"
  mock_outputs = {
    identity_provider_arn = "arn:aws-us-gov:iam::111111111:oidc-provider/s3-us-gov-west-1.amazonaws.com/example"
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

inputs = {
  velero_k8s_service_account = "velero"
  role_name = "${include.root.inputs.cluster_name}-velero"
  policy_name = "${include.root.inputs.cluster_name}-velero"
  identity_provider_arn = dependency.identity_provider.outputs.identity_provider_arn
}
