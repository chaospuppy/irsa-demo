# IRSA Demo
This repository contains the resources needed to create a simple demonstration of how to set up self-hosted IRSA for an RKE2 cluster.

## Demo Goals
- Explain the “why” of IRSA
    - Automate access to AWS resources needed by kubernetes-managed applications
    - Least-privilege (don’t just use one-size-fits all instance profile)
    - Key rotation (self-hosted setup with JWKS)
- Explain the “how” of OIDC in an AWS IAM
    - Brief overview of roles and policies
    - Brief overview of JWT/JWKS
    - Trust relationship between a role and an Identity Provider/JWT claims
- Explain the “how” of Service Account tokens and AWS
    - Private signing key for service account tokens (JWTs)
- Demonstrate how to set up a self-hosted OIDC Identity provider, key generation, JWKS generation, key placement, and use of pod-identity-webhook to provide an application with access to a role and policy for the AWS resources it needs

### IRSA
IRSA stands for IAM Role for Service Accounts.  It is a method for providing kubernetes Service Accounts with IAM roles and policies that are tightly coupled with the operations that need to be performed by the applciations that use the Service Accounts as an identity.

### Why IRSA?
Historically, the surefire method for ensuring that applications hosted in AWS of Kubernetes do not have permissions issues while performing their cloud-aware tasks (such as finding EBS volumes attached to instances via PersistentVolumes, for example) is to attach an uber-powerful role to the kubernetes worker instance that has policy sufficient for *every* workload that it could host.  That means if you have a generic nodepool that could host velero, nexus, harbor, and vault, you would need to attach an instance policy to the generic workers that includes all the IAM actions for all the AWS resources that could possibly be needed by *all four* of these applications.  While this works and it pretty straightforward to set up (`*`s for everyone!) it opens up a whole host of security issues.  Chief among these is that least-privilege in this context is not followed, and if one pod in any of these applications (or any other applications that may be running that don't even require an IAM role) is compromised, the attacker has the maximum possible privileges to wreck havoc with.  IRSA solves this by ensuring that pods only have access to the resources they absolute *need*, so if one pod is compromised, the scope of the attack is limited.

### IAM OIDC for Kubernetes
So how does Kubernetes authenticate its workloads to AWS via an OIDC IdentityProvider?  First, a quick review of some key aspects of Kubernetes and AWS IAM:

- Kubernetes creates JWTs (Json Web Tokens) for each of its workloads, which in turn are used by SerivceAccounts which are then used in all requests eminating from the workload as a means of authentication and authorization (authn/authz).  These JWTs are signed using a key held by the Kubernetes API Service.  By default, Kubrnetes checks the signatures of these JWTs against an internal "issuer" endpoint hosted by the API Service, but this default behavior can be overridden to use a cluster-external issuer.  Additionally, the key used to sign these JWTs is configurable.

- AWS IAM Roles can be configured with a "trust relationship" that allows the Role to be "assumed" by a requesting entity if and only if the JWT passed in the request to the AWS IAM API meets certain criteria and the token's signature is deemed valid by a third-party AWS IdentityProvider.  For example, a Role can have a trust relationship defined that specifies only JWTs whose `sub` (the JWT subject) attributes match a certain string or expression are allowed to assume the Role.  In the case of Kubernetes-generated ServiceAccount JWTs, the `sub` attribute describes the an identity in the form the following form `system:serviceaccount:<namespace>:<serviceaccount-name>`

- The OIDC IdentityProvider resource offered by AWS is a way of providing AWS with a reference to an OIDC Configuration (or openid-configuration) file, which sets some expectations for how the JWT is formed (what the signature algorithm should be, the kinds of responses that should be returned from the IdentityProvider, its own issuer identity, etc.).  Addtionally, the openid-configuration also supplies the location of a set of public keys that represent the public half of the private/public RSA key pair.  This key set is refered to as the Java Web Key Set or JWKS.  Both the JWKS and the openid-configuration resources must be accessible by the IdentityProvider and therefore can be publically *readable*.

So, all together the workflow for IRSA looks like this:
- An openid-configuration and JWKS is created somewhere (an S3 bucket, for example) and an IdentityProvider is set up as a reference to these resources
- An IAM Role with an IAM Policy attached that satisfied the requirements of a particular application running in AWS is created with a trust-relationship attached.  This trust relationship sets out some criteria about what the JWT needs to look like (authorization) as well as the IdentityProvider used to validate the JWT signature (authentication)
- Kubernetes is configured to use the private half of the RSA keypair as a `--service-acount-signing-key` (multiple keys may be specified), and is also configured to use an external `--service-account-issuer` to validate requests made to the Kubernetes API using signatures created with the new signing key (to avoid service distruptions)

### Pod Identity Webhook
Okay, so how does the application get access to and use these ServiceAccount tokens/JWTs to authenticate to AWS?  This is where the [pod-identity-webhook](https://github.com/aws/amazon-eks-pod-identity-webhook) comes into play.  The pod-identity-webhook is deployed into the Kubernetes cluster that has been configured to use the new signing key and issuer and acts as a [MutatingWebhook](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) service that takes the pod definition submitted by the Kubernetes client, and modifies the pod defintion to add a [projected ServiceAccount token](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection), which is then mounted into the pod at a predefined location.  Additionally, the webhook adds a set of environment variables that are used by applications with AWS SDK integration (which is most widely-used applications) indicating where the JWT is inside the pod, what role should be assumed (as specified by an annotation on the ServiceAccount), the token audience, and other data used to contact the AWS API.

At the end of all this, what you have is a workload pod that is AWS-aware, enabling it to make requests to the AWS API that can be authenticated and checked for proper authorization before going on to make the calls to the AWS API under the assumed role.



## Terraform
The terraform in this repository handles the creation of an RKE2 cluster (using some updated modules sourced from https://github.com/rancherfederal/rke2-aws-tf), AWS OIDC IdentityProvider (required for self-hosted), a bucket in which to store the OIDC configuration (required for self-hosted), and a few resources used by the applications used for this demo, such as an S3 bucket for Velero.

## Terragrunt
[Terragrunt](https://terragrunt.gruntwork.io/) is a wrapper around terraform that simplifies and keeps terraform configuration DRY.  It's used out of preference, not necessity.

## Scripts
The `scripts` directory contains a python script `oidc-init.py` that can be used after running terragrunt to generate an RSA keypair, openid-configuration, and jwks before placing the openid-configuration and jwks into the specified S3 bucket.  The private and public keys output by this script can then be used by the Ansible in this repository to provision the Kubernetes API Service after cluster creation.

## Ansible
Ideally, the service account signing keys would be present on the node before the cluster starts, and the Kubernetes API Server would be configured to use them and the external issuer before the cluster is first started.  However, if this isn't possible because downtime required to restart the cluster from scratch is unacceptable and/or the kubernetes provider used to start the cluster does not expose startup configuration for the API Server, the ansible in the `ansible` directory is an example of how (with RKE2) IRSA can be enabled.  The process will look similar across kubernetes providers.

To run this ansible, copy the keys generated by `oidc-init.py` to `ansible/roles/oidc/files/keys/`, update the `inventory.yaml` with the control-plane host IPs, and copy the SSH key generated by the terraform/terragrunt to `ansible/` to allow Ansible to reach the remote hosts.

NOTE: After running Ansible, the Canal pods in the `kube-system` namespace will need to be cycled if the signing key has changed.  Until this is done, you may see Authorization errors related to network sandbox creation in kubernetes Events.

## K8s
The `k8s` directory contains the application helm charts and kustomizations used by this demo.  The deployment order is as follows:
- pre-req (kustomize)
- cert-manager (helm)
- cert-manager-resources (kustomize)
- pod-identity-webhook (kustomize)
- gitea (helm)
- velero (helm)
