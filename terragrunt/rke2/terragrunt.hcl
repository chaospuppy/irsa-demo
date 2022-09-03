include "root" {
  path = find_in_parent_folders()
}

include "rke2" {
  path = "./rke2_vars.hcl"
}

terraform {
  source = "../..//terraform/rke2/"
}
