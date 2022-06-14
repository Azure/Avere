# SMB Walker Performance Testing

Set of scripts and Terraform deployments to set up a test environment for the SMB Walker (link).

## 01 Network and Active Directory

1. Run `cd 01.Network_and_AD` in a local shell (Bash or PowerShell)
1. Review and edit the config values in `config.auto.tfvars` for your deployment.
1. Run `terraform init` to initialize the current local directory (append `-upgrade` if older providers are detected)
1. Run `terraform apply` to generate the Terraform deployment [Plan](https://www.terraform.io/docs/cli/run/index.html#planning) (append `-destroy` to delete Azure resources)
1. Review and confirm the displayed Terraform deployment plan (add, change and/or destroy Azure resources)

AD requires some manual config

## 02 vFXT (or HPC Cache)



## 03 Clients

VMSS