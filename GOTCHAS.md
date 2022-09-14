# Gotchas
- Need to restart all pods after rotating SA signing keys, unless it's possible to specify two `--service-account-issuers`
- Need to use custom AMI for RKE2 nodes to pre-disable networkmanager
