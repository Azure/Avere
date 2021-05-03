# CentOS Rendering End-to-End

This folder contains all the automation to configure all infrastructure described in the [first render pilot](../securedimage/Azure%20First%20Render%20Pilot.pdf).

## 1. Azure Key Vault

The keyvault stores all the secrets used in this example.  Be sure to configure the following Secrets with keys:
* `vpngatewaykey` - this is the subnet to contain the VPN gateway
* `virtualmachine` - this configures the 
* `AvereCache` - this configures the secret to be used with the Avere Cache

## 2. Network

This sets up a VNET with the following subnets:

1. Gateway
2. Cache
3. Render Nodes

## 3. CentOS Stock

## 4. CentOS Image

## 5. Cache

## 6. VMSS