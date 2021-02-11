# Security Best Practices for Rendering

As you build out your cloud burst render solution it is important to understand the security responsibility between you and Microsoft.  The [Shared Responsibility in the cloud](https://docs.microsoft.com/en-us/azure/security/fundamentals/shared-responsibility) document describes in detail the division of responsibility between you and Microsoft:

[![Division of responsibility](https://docs.microsoft.com/en-us/azure/security/fundamentals/media/shared-responsibility/shared-responsibility.png)](https://docs.microsoft.com/en-us/azure/security/fundamentals/shared-responsibility#division-of-responsibility)

# Phase Approach

As you build out your security posture for your division of responsibility described previously, we recommend a multi-phased approach related to the [Microsoft Security Development LifeCycle](https://www.microsoft.com/en-us/securityengineering/sdl):

1. **Learn and Understand**
    1. **Organization** - Learn about your organization's security and what security priorities are most important for your organization.  For example, data exfiltration of artist content may take priority over source code exfiltration.  This includes meeting with the security experts in your organization, learning the existing tools, systems, and practices in place.

    1. **Model and Understand Your Infrastructure** - Understand security as related to your specific infrastructure by drawing an architecture diagram.  One great way method is to use the [Microsoft Threat Modeling tool](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool), or your favorite drawing tool, and draw your infrastructure and layers of security, and check this into your code repository.  This will help you focus and understand your required security posture.  

    1. **Media Industry Best Practices** - use the following ISE hardening guides related to Media to inform your threat modeling:
        * [Review MPA Compliance Offering resources to inform your threat model](https://docs.microsoft.com/en-us/azure/compliance/offerings/offering-mpa)
        * [Editorial and Asset Management Hardening Guide for Azure](https://azure.microsoft.com/mediahandler/files/resourcefiles/editorial-and-asset-management-hardening-guide-for-azure/Editorial_and_Asset_Management_Workflows_Hardening_Guide_for_Azure.pdf)
        * [Independent Security Evaluators Hardening Guide for 3D Graphics Rendering Workflows](https://azure.microsoft.com/mediahandler/files/resourcefiles/azure-media-hardening-guide-for-3d-graphics-rendering/ise-azure-rendering-hardening_guide.pdf)
        * [Azure Virtual Desktop Infrastructure Hardening Guide](https://azure.microsoft.com/en-us/resources/azure-virtual-desktop-infrastructure-hardening-guide/)
    
    1. **Microsoft Security Best Practices** - use Microsoft security best practices to inform your threat model.  Here are some great resources to learn about Microsoft and Azure Security:
        * [Azure Security Best Practices and Patterns](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns) - review the best practices and patterns and apply the security items that align with your infrastructure and threat model.
        * [Azure Security Fundamentals](https://docs.microsoft.com/en-us/azure/security/fundamentals/)
        * [Microsoft Security](https://docs.microsoft.com/en-us/azure/security/) - Security is integrated into every aspect of Azure. Azure offers you unique security advantages derived from global security intelligence, sophisticated customer-facing controls, and a secure hardened infrastructure. This powerful combination helps protect your applications and data, support your compliance efforts, and provide cost-effective security for organizations of all sizes. 
        * [Microsoft Security Youtube Channel](https://www.youtube.com/c/MicrosoftSecurity/videos)
        * [Azure Governance](https://docs.microsoft.com/en-us/azure/governance/)
        * [Azure Governance Youtube Channel](https://www.youtube.com/channel/UCZZ3-oMrVI5ssheMzaWC4uQ/videos)
        * [Azure Security Best Practices and Patterns](https://docs.microsoft.com/en-us/azure/security/fundamentals/best-practices-and-patterns) - review the best practices and patterns and apply the security items that align with your infrastructure and threat model.

1. **Implement**
    1. Assign an security owner to each subscription to ensure accountability on security decisions.
    1. Use infrastructure-as-code like Terraform or Azure Resource Manager Templates, and version and check this into your repository.
    1. Review the security examples in this repository related to rendering:
        * [Avere vFXT in a Proxy Environment](../vfxt/proxy) - this example shows how to deploy the Avere in a locked down internet environment, with a proxy.
        * [Secure VNET](../securevnet) - shows how to create a simple secure VNET that has locked down internet for burst render.
        * [SecuredImage](../securedimage) - shows how to create, upload, and deploy a custom image with an introduction to RBAC, Azure Governance, and Network.
    1. browse and use the governance and security resources of Terraform:
        * [Network Security Groups](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
        * [Azure BluePrints](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/blueprint_assignment)
        * [Azure KeyVault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) - use this to populate the secrets of your Terraform
        * [Azure Security Center](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/advanced_threat_protection)
        * [Azure Sentinel](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/advanced_threat_protection)
    1. Use KeyVault to manage your secrets and combine this with repository secret scanners.
    1. Enable [Azure Security Center](https://azure.microsoft.com/en-us/services/security-center/) to discover easy security holes.

1. **Continuously Evolve and Adapt**
    1. use audit reviews and security incidents in other parts of your organization or industry to evolve your threat model and implementation
    1. Setup quarterly security reviews with your security experts and evolve your threat model, policies, and best practices.
    1. Enable [Azure Sentinel](https://azure.microsoft.com/en-us/services/azure-sentinel/) for continuous security monitoring.
    1. continuously track, prioritize, and complete security related backlog items
    1. work with your security experts to evolve your organizations security posture

# TCO
* Only apply security policies that align with your threat model.  In other words, do not pay for security features that do not add value to your threat model.
    * As a concrete example, for rendering use the no-cost Network Security Groups (NSGs) over Azure Firewall to save cost and latency.
* setup [Azure Cost Management Alerts](https://docs.microsoft.com/en-us/azure/cost-management-billing/cost-management-billing-overview) as this could be a good indicator of attack.
