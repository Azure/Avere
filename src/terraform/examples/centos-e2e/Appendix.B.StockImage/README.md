# Build a CentOS Stock Image

An Azure CentOS Stock Image is a great foundation for a custom image since it contains all the Azure customizations.

These instructions assume use the keyvault and network foundations from the peer folders `0.security` and `1.network`.

Note that as you install software you may have two choices:
1. If you use a proxy, specify the following:
2. Relax the port 80 and port 443 internet outbound rules to reach centos repositories.  As a shortcut, toggle NSG rules on the `rendernodes_nsg` NSG with priority 498 and 499 from `Deny` to `Allow`, and this will open up outbound port 80 and port 443.  Be sure to close the ports when configuration is complete.

# Deployment Instructions

These instructions assume use the keyvault and network foundations from the peer folders `0.security` and `1.network`.

1. `cd ~/tf/src/terraform/examples/centos-e2e/Appendix.C.StockImage`
1. `code config.auto.tfvars` and edit the variables
1. `terraform init -backend-config ../config.backend`
1. `terraform apply -auto-approve -var-file ../config.tfvars`

