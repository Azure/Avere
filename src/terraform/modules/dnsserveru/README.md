# Terraform Module: Azure Virtual Machine Running Unbound (DNS server)

This Terraform module deploys an Azure virtual machine that installs and configures [Unbound](https://nlnetlabs.nl/projects/unbound/about/), which is a recursive DNS resolver that can be used to point the cloud based render nodes at an Avere based cache, instead of a backing core filer under the same name.

The [dnsserver](../../examples/dnsserver) example shows how to deploy this module using Terraform.