# Security Best Practices for Rendering

This document describes the storage cache best practices related to rendering.

# Security Resources
1. [Azure Security Fundamentals](https://docs.microsoft.com/en-us/azure/security/fundamentals/)
1. [Microsoft Security](https://docs.microsoft.com/en-us/azure/security/) - Security is integrated into every aspect of Azure. Azure offers you unique security advantages derived from global security intelligence, sophisticated customer-facing controls, and a secure hardened infrastructure. This powerful combination helps protect your applications and data, support your compliance efforts, and provide cost-effective security for organizations of all sizes. 
1. [Microsoft Security Youtube Channel](https://www.youtube.com/c/MicrosoftSecurity/videos)
1. [Azure Governance](https://docs.microsoft.com/en-us/azure/governance/)
1. [Azure Governance Youtube Channel](https://www.youtube.com/channel/UCZZ3-oMrVI5ssheMzaWC4uQ/videos)
1. [Azure Security Best Practices and Patterns](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns) - review the best practices and patterns and apply the security items that align with your infrastructure and threat model.

# Security Advice Related For Rendering

* Learn about your organization's security and what security priorities are most important for your organization.  For example, data exfiltration of artist content may take priority over source code exfiltration.  This includes meeting with the security experts in your organization, learning the tools and practices in place.
* Understand security as related to your specific infrastructure.  One great way method is to use the [Microsoft Threat Modeling tool](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool), or your favorite drawing tool, and draw your infrastructure and layers of security, and check this into your code repository.  This will help you focus and understand your required security posture.
* Use infrastructure-as-code like Terraform or Azure Resource Manager Templates, and version and check this into your repository.
    * browse and use the governance and security resources of Terraform:
        * [Network Security Groups](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
        * [Azure BluePrints](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/blueprint_assignment)
        * [Azure KeyVault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) - use this to populate the secrets of your Terraform
        * [Azure Security Center](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/advanced_threat_protection)
        * [Azure Sentinel](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/advanced_threat_protection)
* use the following ISE hardening guides related to Media to inform your threat modeling:
    * [Editorial and Asset Management Hardening Guide for Azure](https://azure.microsoft.com/mediahandler/files/resourcefiles/editorial-and-asset-management-hardening-guide-for-azure/Editorial_and_Asset_Management_Workflows_Hardening_Guide_for_Azure.pdf)
    * [Independent Security Evaluators Hardening Guide for 3D Graphics Rendering Workflows](https://azure.microsoft.com/mediahandler/files/resourcefiles/azure-media-hardening-guide-for-3d-graphics-rendering/ise-azure-rendering-hardening_guide.pdf)
    * [Azure Virtual Desktop Infrastructure Hardening Guide](https://azure.microsoft.com/en-us/resources/azure-virtual-desktop-infrastructure-hardening-guide/)
* [Review MPA Compliance Offering resources to inform your threat model](https://docs.microsoft.com/en-us/azure/compliance/offerings/offering-mpa)
* Use KeyVault to manage your secrets and combine this with repository secret scanners.
* Assign an security owner to each subscription to ensure accountability on security decisions.
* Setup quarterly security reviews with your security experts and evolve your threat model, policies, and best practices.
* Review the security examples in this repository related to rendering:
    * [Avere vFXT in a Proxy Environment](../vfxt/proxy) - this example shows how to deploy the Avere in a locked down internet environment, with a proxy.
    * [Secure VNET](../securevnet) - shows how to create a simple secure VNET that has locked down internet for burst render.
    * [SecuredImage](../securedimage) - shows how to create, upload, and deploy a custom image with an introduction to RBAC, Azure Governance, and Network.
* Block in / out Internet using Network SEcurity Groups on the subnets of your VNET.
* Enable [Azure Security Center](https://azure.microsoft.com/en-us/services/security-center/) to discover easy security holes.
* Enable [Azure Sentinel](https://azure.microsoft.com/en-us/services/azure-sentinel/) for continuous security monitoring.

# TCO
* For rendering use Network Security Groups (NSGs) over Azure Firewall to save cost due to no cost to use NSGs, and latency.
* setup [Azure Cost Management Alerts](https://docs.microsoft.com/en-us/azure/cost-management-billing/cost-management-billing-overview) as this could be a good indicator of attack.
* Only apply security policies that align with your threat model.  In other words, don't pay larges amounts for security features that do not add value and do not align with your threat model.