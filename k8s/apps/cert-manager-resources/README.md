# Description
pulling cert-manager from upstream from https://github.com/cert-manager/cert-manager/ and everything related to helm is located in the deploy directory 

we are not using any secrets or kustomization everything will be located in the umbrella directory

To do:
- make to do list
- git repo helm version of the chart we are going to use, likely going to use v0.1.0 found [here](https://github.com/cert-manager/cert-manager/blob/v1.8.0/deploy/charts/cert-manager/Chart.template.yaml) 
- make adam recreate post render patches :)
- can cert manager be istio injected?
- change cluster.yaml so that cert manager is disabled and will be installed through the new bootstrap code
- run konvoy [commands](https://repo1.dso.mil/ironbank-tools/ironbank-documentation/-/blob/master/help/konvoy_upgrade_cluster.md)
