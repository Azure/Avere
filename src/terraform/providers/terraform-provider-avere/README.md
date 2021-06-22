# avere_vfxt

The provider that manages an [Avere vFXT for Azure](https://aka.ms/averedocs) cluster.

The provider has the following features:
* create / destroy the Avere vFXT cluster
* scale-up / scale-down from 3 to 16 nodes
* add or remove corefilers and junctions
* add or remove Azure Blob Storage cloud core filer
* add global or vserver custom settings
* add targeted custom settings for the junctions
* add proxy and ntp information

# Example Usage

More examples deployable from Azure Cloud Shell can be found in the [Avere vFXT for Azure Examples](../../examples/vfxt/).

```terraform

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    avere = {
      source  = "hashicorp/avere"
      version = ">=1.0.0"
    }
  }
}

resource "avere_vfxt" "vfxt" {
    controller_address = "10.0.2.5"
    controller_admin_username = "azureuser"
    // ssh key comes from ~/.ssh/id_rsa otherwise you can specify password
    //controller_admin_password = ""
    
    ntp_servers = "169.254.169.254"
    proxy_uri = "http://10.0.254.250:3128"
    cluster_proxy_uri = "http://10.0.254.250:3128"
    
    location = "eastus"
    azure_resource_group = "avere_vfxt_rg"
    azure_network_resource_group = "eastus_network_rg"
    azure_network_name ="eastus_vnet"
    azure_subnet_name = "cloud_cache_subnet"
    vfxt_cluster_name = "vfxt"
    vfxt_admin_password = "ReplacePassword$"
    vfxt_node_count = 3
    node_cache_size = 4096
    
    azure_storage_filer {
        account_name = "unique0azure0storage0account0name"
        container_name = "tools"
        junction_namespace_path = "/animation-tools"
    }

    core_filer {
        name = "animation"
        fqdn_or_primary_ip = "animation-filer.vfxexample.com"
        cache_policy = "Clients Bypassing the Cluster"
        junction {
            namespace_path = "/animation"
            core_filer_export = "/animation"
        }
        junction {
            namespace_path = "/textures"
            core_filer_export = "/textures"
        }
    }

    core_filer {
        name = "animation_for_vdi"
        fqdn_or_primary_ip = module.nasfiler1.primary_ip
        cache_policy = "Isolated Cloud Workstation"
        junction {
            namespace_path = "/animation-vdi"
            core_filer_export = "/animation"
        }
    }
}
```

# Argument Reference

The following arguments are supported:
* <a name="controller_address"></a>[controller_address](#controller_address) - (Optional if [run_local](#run_local) is set to true) the ip address of the controller.  This address may be public or private.  If private it will need to be reachable from where terraform is executed.
* <a name="controller_admin_username"></a>[controller_admin_username](#controller_admin_username) - (Optional if [run_local](#run_local) is set to true) the admin username to the controller
* <a name="controller_admin_password"></a>[controller_admin_password](#controller_admin_password) - (Optional) only specify if [run_local](#run_local) is set to false and password is to be used to access the key, instead of the ssh key ~/.ssh/id_rsa
* <a name="controller_ssh_port"></a>[controller_ssh_port](#controller_ssh_port) - (Optional) only specify if [run_local](#run_local) is set to false and the ssh is a value other than the default port 22.
* <a name="run_local"></a>[run_local](#run_local) - (Optional) specifies if terraform is run directly on the controller (or similar machine with vfxt.py, az cli, and averecmd).  This defaults to false, and if false, a minimum of [controller_address](#controller_address) and [controller_admin_username](#controller_admin_username) must be set.
* <a name="use_availability_zones"></a>[use_availability_zones](#use_availability_zones) - (Optional) specify true to spread the nodes across availability zones for HA purposes.  By default this is set to false.  This feature only works in [regions that support availability zones](https://azure.microsoft.com/en-us/global-infrastructure/geographies/) and with 3 node clusters.  Note: cluster re-created if modified.
* <a name="allow_non_ascii"></a>[allow_non_ascii](#allow_non_ascii) - (Optional) non-ascii characters can break deployment so this is set to `false` by default.  In more advanced scenarios, the ascii check may be disabled by setting to `true`.
* <a name="location"></a>[location](#location) - (Required) specify the azure region.  Note: cluster re-created if modified.
* <a name="azure_resource_group"></a>[azure_resource_group](#azure_resource_group) - (Required) this is the azure resource group to install the vFXT.  This must be the same resource as the controller, or increase the RBAC scope of the controller's managed identity roles with a different resource group.  Note: cluster re-created if modified.
* <a name="azure_network_resource_group"></a>[azure_network_resource_group](#azure_network_resource_group) - (Required) this is the resource group of the VNET to where the vFXT will be deployed.  Note: cluster re-created if modified.
* <a name="azure_network_name"></a>[azure_network_name](#azure_network_name) - (Required) this is the name of the VNET to where the vFXT will be deployed.  Note: cluster re-created if modified.
* <a name="azure_subnet_name"></a>[azure_subnet_name](#azure_subnet_name) - (Required) this is the name of the subnet to where the vFXT will be deployed.  As a best practice the Avere vFXT should be installed in its own VNET.  Note: cluster re-created if modified.
* <a name="ntp_servers"></a>[ntp_servers](#ntp_servers) - (Optional) A space separated list of up to 3 NTP servers for the Avere to use, otherwise Avere defaults to time.windows.com.
* <a name="timezone"></a>[timezone](#timezone) - (Optional) The clusters local timezone.  Choose from a timezone defined in the [timezone file](timezone.go).  The default is "UTC".
* <a name="dns_server"></a>[dns_server](#dns_server) - (Optional) A space separated list of up to 3 DNS Server IP Addresses.
* <a name="dns_domain"></a>[dns_domain](#dns_domain) - (Optional) Name of the network's DNS domain.
* <a name="dns_search"></a>[dns_search](#dns_search) - (Optional) A space separated list of up to 6 domains to search during host-name resolution.
* <a name="proxy_uri"></a>[proxy_uri](#proxy_uri) - specify the proxy used by `vfxt.py` for the cluster deployment.  The format is usually `https://PROXY_ADDRESS:3128`.  A working example that uses the proxy is described in the [Avere vFXT in a Proxy Environment Example](../../examples/vfxt/proxy).    Note: cluster re-created if modified.
* <a name="cluster_proxy_uri"></a>[cluster_proxy_uri](#cluster_proxy_uri) - (Optional) specify the proxy used be used by the Avere vFXT cluster.  The format is usually `https://PROXY_ADDRESS:3128`.  A working example that uses the proxy is described in the [Avere vFXT in a Proxy Environment Example](../../examples/vfxt/proxy).  Note: cluster re-created if modified.
* <a name="image_id"></a>[image_id](#image_id) - (Optional) specify a custom image id for the vFXT.  This is useful when needing to use a bug fix or there is a marketplace outage.  For more information see the [docs on how to create a custom image for the controller and vfxt](../../examples/vfxt#create-vfxt-controller-from-custom-images).  Alternatively, you can use an older version from the marketplace by running the following command and using the "urn" as the value to the `image_id`: `az vm image list --location westeurope -p microsoft-avere -f vfxt -s avere-vfxt-node --all`.  For example, the following specifies an older urn `image_id = "microsoft-avere:vfxt:avere-vfxt-node:5.3.61"`.  Note: cluster re-created if modified.
* <a name="vfxt_cluster_name"></a>[vfxt_cluster_name](#vfxt_cluster_name) - (Required) this is the name of the vFXT cluster that is shown when you browse to the management ip.  To help Avere support, choose a name that matches the Avere's purpose.  Note: cluster re-created if modified.
* <a name="vfxt_admin_password"></a>[vfxt_admin_password](#vfxt_admin_password) - (Required) the password for the vFXT cluster.  Note: cluster re-created if modified.
* <a name="vfxt_ssh_key_data"></a>[vfxt_ssh_key_data](#vfxt_ssh_key_data) - (Optional) deploy the cluster using the ssh public key for authentication instead of the password, this is useful to align with policies.
* <a name="vfxt_node_count"></a>[vfxt_node_count](#vfxt_node_count) - (Required) the number of nodes to deploy for the Avere cluster.  The count may be a minimum of 3 and a maximum of 16.  If the cluster is already deployed, this will result in scaling up or down to the node count.  It requires about 15 minutes to delete and add each node in a scale-up or scale-down scenario.
* <a name="node_cache_size"></a>[node_cache_size](#node_cache_size) - (Optional) The cache size in GB to use for each Avere vFXT VM.  There are two options: 1024 or 4096 where 4096 is the default value.  Note: cluster re-created if modified.
* <a name="enable_nlm"></a>[enable_nlm](#enable_nlm) - (optional) set to false to disable NLM on the vserver.  By default this is set to true.  Warning: toggling this parameter is destructive and restarts armada and will result in a multi-minute outage.
* <a name="vserver_first_ip"></a>[vserver_first_ip](#vserver_first_ip) - (Optional, but also requires [vserver_ip_count](#vserver_ip_count) to be set) To ensure predictable vserver ranges for dns pre-population, specify the first IP of the vserver.  This will create consecutive ip addresses based on the maximum of [vfxt_node_count](#vfxt_node_count) or [vserver_ip_count](#vserver_ip_count).  The following configuration is recommended:
    1. ensure the Avere vFxt has a dedicated subnet,
    2. consider a range at the end of the subnet, and
    3. consider room for scale-up and add all the addresses.  If you scale-up / scale-down we recommend choosing the max of 32 addresses.
    
  Azure will take the first 4 address (eg. .0-.3 on a /24), and the controller and Avere vFXT will take 2+(n*2) ip addresses where n is the value of the maximum of [vfxt_node_count](#vfxt_node_count) or [vserver_ip_count](#vserver_ip_count) (eg. .4-.10 on a /24 subnet).  Also at the end of the range, Azure will consume the broadcast address (eg. .255 on a /24 subnet).  More details on Azure reserved subnets in the [virtual networks faq](https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq#are-there-any-restrictions-on-using-ip-addresses-within-these-subnets).  The default is to let the deployment automatically add the vserver ip addresses.  Note: cluster re-created if modified.
* <a name="vserver_ip_count"></a>[vserver_ip_count](#vserver_ip_count) - (Optional, but also requires [vserver_first_ip](#vserver_first_ip) to be set).  Set this to the maximum node count that will be used for this cluster.  To avoid an unbalanced load because cluster size is not a multiple, we recommend setting to the max of 32 ip addresses.  Note: cluster re-created if modified.
* <a name="global_custom_settings"></a>[global_custom_settings](#global_custom_settings) - (Optional) these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".
* <a name="vserver_settings"></a>[vserver_settings](#vserver_settings) - (Optional) these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".  Do not prefix with the vserver as it is automatically detected.
* [user](#user) - (Optional) zero or more user blocks to add additional users in addition to the existing admin user role.
* [azure_storage_filer](#azure_storage_filer) - (Optional) zero or more storage filer blocks used to specify zero or more [Azure Blob Storage Cloud core filers](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-deploy-plan#cloud-core-filers).
* [core_filer](#core_filer) - (Optional) zero or more storage filer blocks used to specify zero or more [NFS filers](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-deploy-plan#hardware-core-filers)
* <a name="enable_support_uploads"></a>[enable_support_uploads](#enable_support_uploads) - (Optional) This setting defaults to 'false' and by setting to 'true' you agree to the [Privacy Policy](https://privacy.microsoft.com/en-us/privacystatement) of the Avere vFXT.  This enables support exactly as described in the [Enable Support Uploads documentation](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-enable-support).  Avere vFXT for Azure can automatically upload support data about your cluster. These uploads let support staff provide the best possible customer service.
* <a name="support_uploads_company_name"></a>[support_uploads_company_name](#support_uploads_company_name) - (Optional, but if specified required with `"enable_support_uploads"`) Specifies the customer name on support uploads to help help Avere support identify support packages.  This is only used with support uploads.
* <a name="enable_rolling_trace_data"></a>[enable_rolling_trace_data](#enable_rolling_trace_data) - (Optional, but if specified required with `"enable_support_uploads"`) This setting defaults to 'false' and by setting to 'true' this setting adds the rolling trace option to the `"enable_support_uploads"` feature and is useful for troubleshooting performance issues.
* <a name="rolling_trace_flag"></a>[rolling_trace_flag](#rolling_trace_flag) - (Optional, but if specified required with `"enable_support_uploads"` and `"enable_rolling_trace_data"`) This setting defaults to `0xef401`.  This enables the following:
    * trace debugging
    * local directory operations
    * HA logging
    * tracing for all virtual cache manager (VCM) operations
* <a name="active_support_upload"></a>[active_support_upload](#active_support_upload) - (Optional, but if specified required with `"enable_support_uploads"`) This setting defaults to 'false' and by setting to 'true' this setting will initiate upload on the removal of the last core filer, or deletion of the cluster.  If disabled, the support bundle is uploaded once a day at 01:00 of the vfxt timezone.
* <a name="enable_secure_proactive_support"></a>[enable_secure_proactive_support](#enable_secure_proactive_support) - (Optional, but if specified required with `"enable_support_uploads"`) This setting defaults to 'Disabled', but other options are 'Support', 'API', and 'Full'.  By setting to a value other than 'disabled' you agree to the [Privacy Policy](https://privacy.microsoft.com/en-us/privacystatement) of the Avere vFXT.  By setting this value, you also consent to the automatic support data upload.  Automatically uploaded support data may contain personal data and/or customer content. Use of such data by Microsoft will be in accordance with the Microsoft Privacy statement and EU GDPR terms.
* <a name="cifs_ad_domain"></a>[cifs_ad_domain](#cifs_ad_domain) - (optional, but if specified required with `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_username"`, `"cifs_password"`) Enter the fully qualified domain name (FQDN) of the Active Directory domain that the cluster is to join.  Configure to enable SMB2 on this cluster.
* <a name="cifs_netbios_domain_name"></a>[cifs_netbios_domain_name](#cifs_netbios_domain_name) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_username"`, `"cifs_password"`) The netbios domain name for the domain.  This is the name found on the general tab of the properties dialog for the domain in the Active Directory manager.
* <a name="cifs_dc_addreses"></a>[cifs_dc_addreses](#cifs_dc_addreses) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_server_name"`, `"cifs_username"`, `"cifs_password"`) Enter one to three space-separated domain controller addresses, in IPv4 dotted notation.
* <a name="cifs_server_name"></a>[cifs_server_name](#cifs_server_name) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_username"`, `"cifs_password"`) Enter the name for the CIFS server.  The default value is the name of the cluster, but you can enter a different name if you prefer.  The name can be no longer than 15 characters.  Names can include alphanumeric characters (a-z, A-Z, 0-9) and hyphens (-), but not underscores (_), periods (.), or other special characters.
* <a name="cifs_username"></a>[cifs_username](#cifs_username) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_password"`) Enter the name of a Windows user with permission to join the Active Directory domain configured for the cluster.  The name is specified as either a username (e.g. "jsmith") or username with FQDN suffix (e.g. "jsmith@contoso.com")
* <a name="cifs_password"></a>[cifs_password](#cifs_password) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_username"`) Enter the password for the cifs_username.
* <a name="cifs_flatfile_passwd_uri"></a>[cifs_flatfile_passwd_uri](#cifs_flatfile_passwd_uri) - (optional, but if specified required with `"cifs_flatfile_group_uri"`) HTTP URI of the external password file in /etc/passwd format.  This overrides using AD for users/groups, and instead provides users as flatfile.
* <a name="cifs_flatfile_group_uri"></a>[cifs_flatfile_group_uri](#cifs_flatfile_group_uri) - (optional, but if specified required with `"cifs_flatfile_passwd_uri"`) HTTP URI of the external group file in /etc/group format.  This overrides using AD for users/groups, and instead provides groups as flatfile.
* <a name="cifs_flatfile_passwd_b64z"></a>[cifs_flatfile_passwd_b64z](#cifs_flatfile_passwd_b64z) - (optional, but if specified required with `"cifs_flatfile_group_b64z"`) the b64 gzipped file of the password file in /etc/passwd format.  This overrides using AD for users/groups, and instead provides users as flatfile. This cannot be used with `cifs_flatfile_passwd_uri`
* <a name="cifs_flatfile_group_b64z"></a>[cifs_flatfile_group_b64z](#cifs_flatfile_group_b64z) - (optional, but if specified required with `"cifs_flatfile_passwd_b64z"`)  the b64 gzipped file group file in /etc/group format.  This overrides using AD for users/groups, and instead provides groups as flatfile.  This cannot be used with `cifs_flatfile_group_uri`.
* <a name="cifs_rid_mapping_base_integer"></a>[cifs_rid_mapping_base_integer](#cifs_rid_mapping_base_integer) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_username"`, `"cifs_password"`)  dynamically create the uid and gid flat files by using the relative id (RID) portion of the windows security id (SID). The RID will be added to the base integer.  The base integer can be used to represent each unique forest in an organization.  A recommended integer is something larger than 1000000000.  For example, 1087660000 could be a good base integer that will allow rids up to 9999.  This cannot be used with `cifs_flatfile_group_uri` or `cifs_flatfile_passwd_b64z`.  The default is `0` and `0` represents disabled.  A value great than `0` enables the RID user and group mapping.
* <a name="cifs_organizational_unit"></a>[cifs_organizational_unit](#cifs_organizational_unit) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_username"`, `"cifs_password"`) the organizational unit for the machine account to be created in.
* <a name="cifs_trusted_active_directory_domains"></a>[cifs_trusted_active_directory_domains](#cifs_trusted_active_directory_domains) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_username"`, `"cifs_password"`) A space-separated list of names of trusted Active Directory domains to download user/group data from.  By default this is empty to only download data from the domain the FXT is joined to.  Set to '*' to download data from all known trusted domains.
* <a name="enable_extended_groups"></a>[enable_extended_groups](#enable_extended_groups) - (optional, but if specified required with `"cifs_ad_domain"`, `"cifs_netbios_domain_name"`, `"cifs_dc_addreses"`, `"cifs_server_name"`, `"cifs_username"`, `"cifs_password"`) set to true to enable extended groups to support users that are in more than 16 authsys groups. By default this is set to false.
* <a name="user_assigned_managed_identity"></a>[user_assigned_managed_identity](#user_assigned_managed_identity) - (optional) set to a user assigned managed identity that will be used by the vFXT nodes.  This should have a minimum of role assignment of "[Avere Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-operator)" with scope of the vFXT resource group.  See the [Managed Identities Section](#managed-identities) to learn more.
* <a name="login_services_ldap_server"></a>[login_services_ldap_server](#login_services_ldap_server) - (optional, but if specified required with `"login_services_ldap_basedn"`, `"login_services_ldap_binddn"`, `"login_services_ldap_bind_password"`) - is one of the parameters to configure an LDAP or Active Directory (AD) server to supply usernames and groups for authorizing access to the Avere Control Panel ([more details on loginservices](https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_login_services.html)).  Here is a concrete example of how to enable login services:
```terraform
    login_services_ldap_server = "rendering.com"
    login_services_ldap_basedn = "dc=rendering,dc=com"
    login_services_ldap_binddn = "CN=azureuser,CN=Users,DC=rendering,DC=com"
    login_services_ldap_bind_password = "ReplacePassword"
```
* <a name="login_services_ldap_basedn"></a>[login_services_ldap_basedn](#login_services_ldap_basedn) - (optional, but if specified required with `"login_services_ldap_server"`, `"login_services_ldap_binddn"`, `"login_services_ldap_bind_password"`) - is one of the parameters to configure an LDAP or Active Directory (AD) server to supply usernames and groups for authorizing access to the Avere Control Panel ([more details on loginservices](https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_login_services.html)).
* <a name="login_services_ldap_binddn"></a>[login_services_ldap_binddn](#login_services_ldap_binddn) - (optional, but if specified required with `"login_services_ldap_server"`, `"login_services_ldap_basedn"`, `"login_services_ldap_bind_password"`) - is one of the parameters to configure an LDAP or Active Directory (AD) server to supply usernames and groups for authorizing access to the Avere Control Panel ([more details on loginservices](https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_login_services.html)).
* <a name="login_services_ldap_bind_password"></a>[login_services_ldap_bind_password](#login_services_ldap_bind_password) - (optional, but if specified required with `"login_services_ldap_server"`, `"login_services_ldap_basedn"`, `"login_services_ldap_binddn"`) - is one of the parameters to configure an LDAP or Active Directory (AD) server to supply usernames and groups for authorizing access to the Avere Control Panel ([more details on loginservices](https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_login_services.html)).
* <a name="tags"></a>[tags](#tags) - (optional) A map of tags assigned to the Azure resources created by this terraform resource.  Note: cluster re-created if modified.
---

A <a name="user"></a>`user` block supports the following
* <a name="user"></a>[user](#user) - (Required) the user name, must not be blank, or match with an existing user including the `admin` username.  The username can contain only alphanumeric characters and must have a length of no more than 60 characters.
* <a name="password"></a>[password](#password) - (Required) The user's password.  The password must have a length of no more than 36 characters.
* <a name="permission"></a>[permission](#permission) - (Required)  One of the following:
    * 'rw' for read-write administrative access,
    * 'ro' for read-only administrative access

---

A <a name="azure_storage_filer"></a>`azure_storage_filer` block supports the following
* <a name="account_name"></a>[account_name](#account_name) - (Required) specifies the Azure storage account name for the cloud filer.
* <a name="container_name"></a>[container_name](#container_name) - (Required) specifies the Azure storage blob container name to use for the cloud filer.
* <a name="ordinal_1"></a>[ordinal](#ordinal_1) - (Optional) - this specifies the order that the storage filers are added. The default is 0, and the core filers are added in ascending numerical order followed by ascending alphabetical order on name.
* <a name="custom_settings_1"></a>[custom_settings](#custom_settings_1) - (Optional) - these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".  Do not prefix with the mass name as it is automatically detected.
* <a name="junction_namespace_path"></a>[junction_namespace_path](#junction_namespace_path) - (Optional) this is the exported namespace from the Avere vFXT.
* <a name="cifs_share_name_1"></a>[cifs_share_name](#cifs_share_name_1) - (Optional) this is an SMB2 share exported from the Avere vFXT.
* <a name="cifs_share_ace_1"></a>[cifs_share_ace](#cifs_share_ace_1) - (Optional) this is an export rule described in the [CIFS Share ACE section](#cifs-share-ace).  If not specified, the junction uses the most permissive access set to `Everyone`.
* <a name="cifs_create_mask_1"></a>[cifs_create_mask](#cifs_create_mask_1) - (Optional) An octal value specifying the bitwise mask for the UNIX permissions for a newly created file.  If not specified, the default is 0744 for file create, and 0777 when modified from a native Windows NT security dialog box.
* <a name="cifs_dir_mask_1"></a>[cifs_dir_mask](#cifs_dir_mask_1) - (Optional) An octal value specifying the bitwise mask for the UNIX permissions for a newly created directory.  If not specified, the default is 0755 for directory create, and 0777 when modified from a native Windows NT security dialog box.
* <a name="export_rule_1"></a>[export_rule](#export_rule_1) - (Optional) this is an export rule described in the [Export Rules section](#export-rules).  If not specified, the junction uses the most permissive rule set by the default policy.

---

A <a name="core_filer"></a>`core_filer` block supports the following:
* <a name="name"></a>[name](#name) - (Required) the unique name for the core filer
* <a name="fqdn_or_primary_ip"></a>[fqdn_or_primary_ip](#fqdn_or_primary_ip) - (Required)  The primary IP address or fully qualified domain name of the core filer.  This may also be a space-separated list of IP addresses or domain names, where subsequent network names are used in advanced networking configurations.
* <a name="filer_class"></a>[filer_class](#filer_class) - (Optional) One of the following predefined values that describes this core filer. If no CIFS ACL junctions will exist to the core filer then the default of "Other" may be used.  NetApp clusters newer than 2016 generally use C-mode or `NetappClustered`; to confirm run `showmount -e` against the ip , and it shows `'/'` then it is a clustered netapp.
    * NetappNonClustered
    * NetappClustered
    * EmcIsilon
    * Other
* <a name="cache_policy"></a>[cache_policy](#cache_policy) - (Required) the cache policy for the core filer. and can be any of the following values:
    | Cache_policy string | Description |
    | --- | --- |
    | "Clients Bypassing the Cluster" | Use this cache policy when some of your clients are mounting the Avere cluster and others are mounting the core filer directly. |
    | "Clients Bypassing the Cluster**N**" | This uses "Clients Bypassing the Cluster" as the foundation, but then allows you to set an integer number for N greater than or equal to 0 for the check attribute period. |
    | "Read Caching" | Use this cache policy when file read performance is the most critical resource of your workflow. |
    | "Read and Write Caching" | Use this cache policy when a balance of read and write performance is desired. |
    | "Full Caching" | Use this cache policy with cloud core filers or to optimize for op reduction to the core filer. |
    | "Isolated Cloud Workstation" | useful for vdi workstations reading and writing to separate locations as described in [Cloud Workstations](../../examples/vfxt/cloudworkstation) |
    | "Collaborating Cloud Workstation" | useful for vdi workstations reading and writing to the same content as described in [Cloud Workstations](../../examples/vfxt/cloudworkstation) |
    | "Read Only High Verification Time" | Use this for read heavy data, where changes in the data are infrequent. |
* <a name="auto_wan_optimize"></a>[auto_wan_optimize](#auto_wan_optimize) - (Optional) - enables best core filer performance over a WAN.  The default is true, since most applications will be to an on-prem core filer.  Also, autoWanOptimize it not required for storage filers as it is always automatically applied for cloud storage filers.
* <a name="nfs_connection_multiplier"></a>[nfs_connection_multiplier](#nfs_connection_multiplier) - (Optional) Use this to parallelize the number of calls to the core filer.  The default is 4, but the range is [1,23].
* <a name="ordinal_2"></a>[ordinal](#ordinal_2) - (Optional) - this specifies the order that the core filers are added. The default is 0, and the core filers are added in ascending numerical order followed by ascending alphabetical order on name.
* <a name="fixed_quota_percent"></a>[fixed_quota_percent](#fixed_quota_percent) - (Optional) - specifies the percent of the cache to be initially set when created, but will float dynamically depending on cache usage.  A default of 0 means to use the default provided by the cache.  The fixed quota percent are integers of range [0,100], and the sum must not exceed 100.  The quota is only balanced when starting from no core filers: if one or more core filers exists, then no balancing will occur.
* <a name="custom_settings_2"></a>[custom_settings](#custom_settings_2) - (Optional) - these are custom settings provided by Avere support to match advanced use case scenarios.  They are a list of strings of the form "SETTINGNAME CHECKCODE VALUE".  Do not prefix with the mass name as it is automatically detected.
* [junction](#junction) - (Required) this specifies the junction block as described below.
 
---

A <a name="junction"></a>`junction` block supports the following:
* <a name="namespace_path"></a>[namespace_path](#namespace_path) - (Required) this is the exported namespace from the Avere vFXT. 
* <a name="cifs_share_name_2"></a>[cifs_share_name](#cifs_share_name_2) - (Optional) this is an SMB2 share exported from the Avere vFXT. 
* <a name="core_filer_cifs_share_name"></a>[core_filer_cifs_share_name](#core_filer_cifs_share_name) - (Optional) this is the CIFS share name on the core filer, and may only be specified for the Netapp* and EmcIsilon modes.  Specifying this automatically causes the junction to use 'cifs' access instead of 'posix' access. 
* <a name="cifs_share_ace_2"></a>[cifs_share_ace](#cifs_share_ace_2) - (Optional) this is an export rule described in the [CIFS Share ACE section](#cifs-share-ace).  If not specified, the junction uses the most permissive access set to `Everyone`.
* <a name="cifs_create_mask_2"></a>[cifs_create_mask](#cifs_create_mask_2) - (Optional) An octal value specifying the bitwise mask for the UNIX permissions for a newly created file.  If not specified, the default is 0744 for file create, and 0777 when modified from a native Windows NT security dialog box.
* <a name="cifs_dir_mask_2"></a>[cifs_dir_mask](#cifs_dir_mask_2) - (Optional) An octal value specifying the bitwise mask for the UNIX permissions for a newly created directory.  If not specified, the default is 0755 for directory create, and 0777 when modified from a native Windows NT security dialog box.
* <a name="core_filer_export"></a>[core_filer_export](#core_filer_export) - (Required) this is the export from the hardware core filer.
* <a name="export_subdirectory"></a>[export_subdirectory](#export_subdirectory) - (Optional) if the export does not point directly to the core filer directory that you want to associate with this junction, add the relative subdirectory path here.  (Do not begin the path with "/".)  If the subdirectory does not already exist, it will be created automatically.
* <a name="export_rule_2"></a>[export_rule](#export_rule_2) - (Optional) this is an export rule described in the [Export Rules section](#export-rules).  If not specified, the junction uses the most permissive rule set by the default policy.

# Export Rules

Each junction may specify export rules.  The export rules control client access to core filer exports.  More detailed information on export rules can be found in the [Avere OS Configuration Guide](https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_export_rules.html#export-rules) or the [XML-RPC API Guide](https://azure.github.io/Avere/legacy/pdf/avere-os-5-1-xmlrpc-api-2019-01.pdf) under the method `nfs.addRule`.

The `export_rule` is of the format `"<host1>(<options>) <host2>(<options>)..."`.  The host may be a fully qualified domain name, an IP address, an IP address with a mask (CIDR notation), or '*' to represent all clients.

The options describe the access rules and are specified in any order as follows:
* **access level** - the access level may be read-only `ro` or read/write `rw`.  If not specified, the default is `ro`.
* **squash** - this setting determines how user identities are sent to the core filer, and one of the following three modes may be specified.  If not specified, the default is `all_squash`.
    1. `no_root_squash` - UIDs are passed verbatim from the client to the core filer.
    1. `root_squash` - this will map the root user to the anonymous user (-2)
    1. `all_squash` - this will map all user ids to the anonymous user (-2)
* **allow SUID bits** - specify `allow_suid` if you want to allow files on the core filer to change user IDs (SUID) and group IDs (SGID) upon client access.  If not specified, the default is to disable.  
* **allow submounts** - specify `allow_submounts` to let clients also access subdirectories of the core filer export point.  If not specified, the default is to disable.

**Example 1:** `export_rule = "10.0.0.5"` or  `export_rule = "10.0.0.5()"`

This rule will restrict junction access to only host `10.0.0.5` with all the settings mapped to their default values:
| Access Parameter | Value |
| --- | --- |
| access level | `ro` |
| squash | `all_root_squash` |
| allow SUID bits | `no` |
| allow submounts | `no` |

**Example 2:** `export_rule = "rendermanager.vfx.com(rw,no_root_squash,allow_suid,allow_submounts) 10.0.1.0/24(rw,no_root_squash,allow_suid,allow_submounts) *()"`

This rule enables the following junction access to host `rendermanager.vfx.com` and IP range `10.0.1.0/24`:
| Access Parameter | Value |
| --- | --- |
| access level | `rw` |
| squash | `no_root_squash` |
| allow SUID bits | `yes` |
| allow submounts | `yes` |

All other hosts will be restricted to the following access:
| Access Parameter | Value |
| --- | --- |
| access level | `ro` |
| squash | `all_root_squash` |
| allow SUID bits | `no` |
| allow submounts | `no` |

**Example 3:** `export_rule = ""` or `export_rule` not specified

This rule causes no action to be taken, and the junction inherits the default policy where all hosts `"*"` have the following settings:
| Access Parameter | Value |
| --- | --- |    
| access level | `rw` |
| squash | `no_root_squash` |
| allow SUID bits | `yes` |
| allow submounts | `yes` |

# CIFS Share ACE

Each CIFS share may specify a share ACE to control access to the share.  More information about CIFS management can be found in the [Active Directory Administrator Guide to Avere FXT Deployment](https://azure.github.io/Avere/legacy/pdf/ADAdminCIFSACLsGuide_20140716.pdf).

The `cifs_share_ace` is of the form `"<user1/group1>(<options>) <user2/group2>(<options>)..."`.  The user or group may be a name or security ID (SID).  The name may also include the domain prefix (for example, 'DOMAIN\UserOrGroup').

The options describe the access rules and are specified in any order as follows:
* **type** - the type of ACE (either 'ALLOW' or 'DENY')
* **permission** - the type of permission being allowed or denied - either 'READ', 'CHANGE', or "FULL".

**Example 1:** `cifs_share_ace = "azureuser"` or  `cifs_share_ace = "azureuser()"`

This rule will restrict cifs share access to only user `azureuser` with all the settings mapped to their default values:
| Access Parameter | Value |
| --- | --- |
| type | `ALLOW` |
| permission | `READ` |

**Example 2:** `cifs_share_ace = "RENDERING\rendergroup(ALLOW,FULL) RENDERING\renderwranglers(ALLOW,FULL)"`

This rule will restrict cifs share access to group `RENDERING\rendergroup` and group `RENDERING\renderwranglers` with the following values:
| Access Parameter | Value |
| --- | --- |
| type | `ALLOW` |
| permission | `FULL` |

**Example 3:** `cifs_share_ace = ""` or `cifs_share_ace` not specified

This rule causes no action to be taken, and the junction inherits the default policy where group `Everyone` has the following settings:
| Access Parameter | Value |
| --- | --- |
| type | `ALLOW` |
| permission | `FULL` |

# Managed Identities

Managed identities are a way to grant access to azure resources from virtual machines.  More information can be seen in the [Managed Identity Document](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview).  By default the Avere vFXT is created with a system assigned managed identity.  However, customers may want to choose user assigned identities since this means the controller or machine running `vfxt.py` does not have to be created with powerful roles of `Owner` or `User Access Administrator`.

The Avere provider accepts a user defined managed identity through argument `user_assigned_managed_identity`.  This identity is installed via a controller or machine with `vfxt.py` that also needs a user defined managed identity.  Terraform is used to deploy the controller, and it needs a principal setup with roles.  The following table shows these three levels of identity with the resource group (RG) scopes and built-in role assignments required for each managed identity:

   | Principal or Managed Identity | Description | Managed Identity RG Scope | VNET RG Scope | Storage RG Scope | VFXT RG Scope |
   | --- | --- | --- | --- | --- | --- |
   | **(Principal) Terraform Deployer**  | deploy vFXT controller and vFXT | [Managed Identity Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator) | [Network Contributor](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#network-contributor) | [Storage Account Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#storage-account-contributor), [Virtual Machine Contributor](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor) | [Managed Identity Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator), [Avere Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-contributor), [Virtual Machine Contributor](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#virtual-machine-contributor), [Network Contributor](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#network-contributor) |
   | **(Managed Identity) Controller** | used to create, destroy, and manage a vFXT cluster | [Managed Identity Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator) | [Avere Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-contributor) | [Avere Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-contributor) | [Managed Identity Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator), [Avere Contributor](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-contributor) |
   | **(Managed Identity) vFXT** | the vFXT manages Azure resources for new vServers, and in response to HA events |  | [Avere Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-operator)  | [Avere Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-operator) | [Avere Operator](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#avere-operator) |

An example that shows the creation of the above principal and managed identities is the [User Assigned Managed Identity](../../examples/vfxt/user-assigned-managed-identity/) example.

# Attributes Reference

In addition to all arguments above, the following attributes are exported:
* <a name="vfxt_management_ip"></a>[vfxt_management_ip](#vfxt_management_ip) - this is the Avere vFXT management ip address.
* <a name="vserver_ip_addresses"></a>[vserver_ip_addresses](#vserver_ip_addresses) - these are the list of vserver ip addresses.  Clients will mount to these addresses.
* <a name="node_names"></a>[node_names](#node_names) - these are the node names of the cluster.
* <a name="primary_cluster_ips"></a>[primary_cluster_ips](#primary_cluster_ips) - these are the static primary ip addresses of the cluster that do not move.
* <a name="mass_filer_mappings"></a>[mass_filer_mappings](#mass_filer_mappings) - these are the static primary ip addresses of the cluster that do not move.

# Build the Terraform Provider binary on Linux

There are three approaches to access the provider binary:
1. Download from the [releases page](https://github.com/Azure/Avere/releases).
2. Deploy the [jumpbox](../../examples/jumpbox) - the jumpbox automatically builds the provider.
3. Build the binary using the instructions below.

_Note_: The provider is built as a go module - this lets you build outside your GOPATH.

The following build instructions work in https://shell.azure.com, Centos, or Ubuntu:

1. if this is centos, install git

    ```bash
    sudo yum install git
    ```

2. If not already installed go, install golang:

    ```bash
    wget https://dl.google.com/go/go1.14.linux-amd64.tar.gz
    tar xvf go1.14.linux-amd64.tar.gz
    mkdir ~/gopath
    echo "export GOPATH=$HOME/gopath" >> ~/.profile
    echo "export PATH=\$GOPATH/bin:$HOME/go/bin:$PATH" >> ~/.profile
    echo "export GOROOT=$HOME/go" >> ~/.profile
    source ~/.profile
    rm go1.14.linux-amd64.tar.gz
    ```

3. build the provider code
    ```bash
    # checkout Checkpoint simulator code, all dependencies and build the binaries
    cd $GOPATH
    go get -v github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    cd src/github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
    go mod download
    go mod tidy
    go build
    version=$(curl -s https://api.github.com/repos/Azure/Avere/releases/latest | jq -r .tag_name | sed -e 's/[^0-9]*\([0-9].*\)$/\1/')
    mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64
    cp terraform-provider-avere ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64
    ```

4. Install the provider `~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64/terraform-provider-avere` to the ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/$version/linux_amd64 directory of your terraform environment, where $version is the version of the provider.

# Build the Terraform Provider binary on Windows

Here are the instructions for building the windows binary:

1. browse to https://git-scm.com/download/win and install git.

1. browse to https://golang.org/doc/install and install golang.

1. open a new powershell command prompt and type the following to checkout the code:

```powershell
mkdir $env:GOPATH -Force
cd $env:GOPATH
go get -v github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
cd $env:GOPATH\src\github.com\Azure\Avere\src\terraform\providers\terraform-provider-avere
go mod download
go mod tidy
go build
```

1. copy the .exe to the source directory
