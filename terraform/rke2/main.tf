data "aws_ami" "rhel7" {
  most_recent = true
  owners      = ["219670896067"] # owner is specific to aws gov cloud

  filter {
    name   = "name"
    values = ["RHEL-7*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_ami" "rhel8" {
  most_recent = true
  owners      = ["219670896067"] # owner is specific to aws gov cloud

  filter {
    name   = "name"
    values = ["RHEL-8*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Key Pair
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "ssh_pem" {
  filename        = "${var.cluster_name}.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "0600"
}

#
# Server
#
module "rke2" {
  source = "../vendor/rke2"

  cluster_name        = var.cluster_name
  vpc_id              = var.vpc_id
  subnets             = var.subnet_ids
  ami                 = data.aws_ami.rhel8.image_id
  ssh_authorized_keys = [tls_private_key.ssh.public_key_openssh]
  instance_type       = "t3a.medium"
  servers             = 1

  # Enable AWS Cloud Controller Manager
  enable_ccm = true

  rke2_config = <<-EOT
node-label:
  - "name=server"
  - "os=rhel8"
EOT

  tags = var.tags
}

#
# Generic agent pool
#
module "agents" {
  source = "../vendor/rke2/modules/agent-nodepool"

  name    = "generic"
  vpc_id  = var.vpc_id
  subnets = var.subnet_ids # Note: Public subnets used for demo purposes, this is not recommended in production

  ami                 = data.aws_ami.rhel8.image_id # Note: Multi OS is primarily for example purposes
  ssh_authorized_keys = [tls_private_key.ssh.public_key_openssh]
  spot                = true
  asg                 = { min : 1, max : 1, desired : 1 }
  instance_type       = "t3a.medium"

  # Enable AWS Cloud Controller Manager and Cluster Autoscaler
  enable_ccm        = true
  enable_autoscaler = true

  rke2_config = <<-EOT
node-label:
  - "name=generic"
  - "os=rhel8"
EOT

  cluster_data = module.rke2.cluster_data

  tags = var.tags
}

resource "aws_security_group_rule" "quickstart_ssh" {
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = module.rke2.cluster_data.cluster_sg
  type              = "ingress"
  cidr_blocks       = ["172.23.0.0/16"]
}

resource "aws_security_group_rule" "kubeapi" {
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = module.rke2.cluster_data.cluster_sg
  type              = "ingress"
  cidr_blocks       = ["172.23.0.0/16"]
}

# Generic outputs as examples
output "rke2" {
  value = module.rke2
}

# Example method of fetching kubeconfig from state store, requires aws cli and bash locally
resource "null_resource" "kubeconfig" {
  depends_on = [module.rke2]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "aws s3 cp ${module.rke2.kubeconfig_path} rke2.yaml"
  }
}
