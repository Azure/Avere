# Azure Terraform NFS based IaaS NAS Filer using ephemeral storage

This version is identical to the NFS Filer example, but sends the script as customdata.  Many versions of Linux do not support cloud init, and this shows how to solve for those environments.