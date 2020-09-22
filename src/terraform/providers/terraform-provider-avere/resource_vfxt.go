// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bytes"
	"fmt"
	"log"
	"regexp"
	"sort"
	"time"

	"github.com/hashicorp/terraform-plugin-sdk/helper/hashcode"
	"github.com/hashicorp/terraform-plugin-sdk/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/helper/validation"
	"github.com/terraform-providers/terraform-provider-azurerm/azurerm/helpers/validate"
	"github.com/terraform-providers/terraform-provider-azurerm/azurerm/utils"

	"golang.org/x/crypto/ssh"
)

func resourceVfxt() *schema.Resource {
	return &schema.Resource{
		Create: resourceVfxtCreate,
		Read:   resourceVfxtRead,
		Update: resourceVfxtUpdate,
		Delete: resourceVfxtDelete,

		Schema: map[string]*schema.Schema{
			controller_address: {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			controller_admin_username: {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			controller_admin_password: {
				Type: schema.TypeString,
				// the ssh key will be used if the password is not specified
				Optional:  true,
				Sensitive: true,
			},
			controller_ssh_port: {
				Type:         schema.TypeInt,
				Optional:     true,
				ValidateFunc: validation.IntBetween(0, 65535),
			},
			run_local: {
				Type:     schema.TypeBool,
				Optional: true,
				Default:  false,
			},
			allow_non_ascii: {
				Type:     schema.TypeBool,
				Optional: true,
				Default:  false,
			},
			location: {
				Type:         schema.TypeString,
				Required:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			platform: {
				Type:         schema.TypeString,
				Default:      PlatformAzure,
				Optional:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			azure_resource_group: {
				Type:         schema.TypeString,
				Required:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			azure_network_resource_group: {
				Type:         schema.TypeString,
				Required:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			azure_network_name: {
				Type:         schema.TypeString,
				Required:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			azure_subnet_name: {
				Type:         schema.TypeString,
				Required:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			ntp_servers: {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			timezone: {
				Type:         schema.TypeString,
				Optional:     true,
				Default:      DefaultTimezone,
				ValidateFunc: validation.StringInSlice(GetSupportedTimezones(), false),
			},
			dns_server: {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			dns_domain: {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			dns_search: {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			proxy_uri: {
				Type:         schema.TypeString,
				Optional:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringDoesNotContainAny(" '\"$"),
			},
			cluster_proxy_uri: {
				Type:         schema.TypeString,
				Optional:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringDoesNotContainAny(" '\"$"),
			},
			image_id: {
				Type:         schema.TypeString,
				Optional:     true,
				ForceNew:     true,
				ValidateFunc: validation.StringDoesNotContainAny(" '\"$"),
			},
			vfxt_cluster_name: {
				Type:         schema.TypeString,
				Required:     true,
				ForceNew:     true,
				ValidateFunc: ValidateVfxtName,
			},
			vfxt_admin_password: {
				Type:         schema.TypeString,
				Required:     true,
				ForceNew:     true,
				Sensitive:    true,
				ValidateFunc: validation.StringDoesNotContainAny(" '\""),
			},
			vfxt_ssh_key_data: {
				Type:         schema.TypeString,
				Optional:     true,
				ForceNew:     true,
				ValidateFunc: ValidateSSHKey,
			},
			vfxt_node_count: {
				Type:         schema.TypeInt,
				Required:     true,
				ValidateFunc: validation.IntBetween(MinNodesCount, MaxNodesCount),
			},
			node_size: {
				Type:     schema.TypeString,
				Optional: true,
				ForceNew: true,
				Default:  ClusterSkuProd,
				ValidateFunc: validation.StringInSlice([]string{
					ClusterSkuUnsupportedTest,
					ClusterSkuProd,
				}, false),
			},
			node_cache_size: {
				Type:     schema.TypeInt,
				Optional: true,
				ForceNew: true,
				Default:  4096,
				ValidateFunc: validation.IntInSlice([]int{
					1024,
					4096,
				}),
			},
			vserver_first_ip: {
				Type:         schema.TypeString,
				Optional:     true,
				ForceNew:     true,
				Default:      "",
				ValidateFunc: validation.IsIPv4Address,
				RequiredWith: []string{vserver_ip_count},
			},
			vserver_ip_count: {
				Type:         schema.TypeInt,
				Optional:     true,
				ForceNew:     true,
				ValidateFunc: validation.IntBetween(MinVserverIpCount, MaxVserverIpCount),
				RequiredWith: []string{vserver_first_ip},
			},
			global_custom_settings: {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: ValidateCustomSetting,
				},
				Set: schema.HashString,
			},
			vserver_settings: {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: ValidateCustomSetting,
				},
				Set: schema.HashString,
			},
			enable_support_uploads: {
				Type:     schema.TypeBool,
				Optional: true,
				Default:  false,
			},
			cifs_ad_domain: {
				Type:         schema.TypeString,
				Optional:     true,
				Default:      "",
				ValidateFunc: ValidateCIFSDomain,
				RequiredWith: []string{cifs_server_name, cifs_username, cifs_password},
			},
			cifs_server_name: {
				Type:         schema.TypeString,
				Optional:     true,
				Default:      "",
				ValidateFunc: ValidateCIFSServerName,
				RequiredWith: []string{cifs_ad_domain, cifs_username, cifs_password},
			},
			cifs_username: {
				Type:         schema.TypeString,
				Optional:     true,
				Default:      "",
				ValidateFunc: ValidateCIFSUsername,
				RequiredWith: []string{cifs_ad_domain, cifs_server_name, cifs_password},
			},
			cifs_password: {
				Type:         schema.TypeString,
				Optional:     true,
				Sensitive:    true,
				Default:      "",
				ValidateFunc: validation.StringDoesNotContainAny(" '\""),
				RequiredWith: []string{cifs_ad_domain, cifs_server_name, cifs_username},
			},
			cifs_flatfile_passwd_uri: {
				Type:          schema.TypeString,
				Optional:      true,
				Default:       "",
				ValidateFunc:  validation.StringDoesNotContainAny(" '\""),
				RequiredWith:  []string{cifs_ad_domain, cifs_server_name, cifs_password, cifs_flatfile_group_uri},
				ConflictsWith: []string{cifs_flatfile_passwd_b64z, cifs_flatfile_group_b64z},
			},
			cifs_flatfile_group_uri: {
				Type:          schema.TypeString,
				Optional:      true,
				Default:       "",
				ValidateFunc:  validation.StringDoesNotContainAny(" '\""),
				RequiredWith:  []string{cifs_ad_domain, cifs_server_name, cifs_password, cifs_flatfile_passwd_uri},
				ConflictsWith: []string{cifs_flatfile_passwd_b64z, cifs_flatfile_group_b64z},
			},
			cifs_flatfile_passwd_b64z: {
				Type:          schema.TypeString,
				Optional:      true,
				Default:       "",
				ValidateFunc:  validation.StringDoesNotContainAny(" '\""),
				RequiredWith:  []string{cifs_ad_domain, cifs_server_name, cifs_password, cifs_flatfile_group_b64z},
				ConflictsWith: []string{cifs_flatfile_passwd_uri, cifs_flatfile_group_uri},
			},
			cifs_flatfile_group_b64z: {
				Type:          schema.TypeString,
				Optional:      true,
				Default:       "",
				ValidateFunc:  validation.StringDoesNotContainAny(" '\""),
				RequiredWith:  []string{cifs_ad_domain, cifs_server_name, cifs_password, cifs_flatfile_passwd_b64z},
				ConflictsWith: []string{cifs_flatfile_passwd_uri, cifs_flatfile_group_uri},
			},
			cifs_organizational_unit: {
				Type:         schema.TypeString,
				Optional:     true,
				Default:      "",
				ValidateFunc: ValidateOrganizationalUnit,
				RequiredWith: []string{cifs_ad_domain, cifs_server_name, cifs_username, cifs_password},
			},
			enable_extended_groups: {
				Type:         schema.TypeBool,
				Optional:     true,
				Default:      false,
				RequiredWith: []string{cifs_ad_domain, cifs_server_name, cifs_username, cifs_password},
			},
			user_assigned_managed_identity: {
				Type:         schema.TypeString,
				Optional:     true,
				Default:      "",
				ValidateFunc: validation.StringDoesNotContainAny(" '\""),
			},
			user: {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Resource{
					Schema: map[string]*schema.Schema{
						name: {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: ValidateUserName,
						},
						password: {
							Type:         schema.TypeString,
							Required:     true,
							Sensitive:    true,
							ValidateFunc: validation.StringLenBetween(1, 36),
						},
						permission: {
							Type:     schema.TypeString,
							Required: true,
							ValidateFunc: validation.StringInSlice([]string{
								UserReadOnly,
								UserReadWrite,
							}, false),
						},
					},
				},
				Set: resourceAvereUserReferenceHash,
			},
			core_filer: {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Resource{
					Schema: map[string]*schema.Schema{
						core_filer_name: {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						fqdn_or_primary_ip: {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						cache_policy: {
							Type:     schema.TypeString,
							Required: true,
							ValidateFunc: validation.StringInSlice([]string{
								CachePolicyClientsBypass,
								CachePolicyReadCaching,
								CachePolicyReadWriteCaching,
								CachePolicyFullCaching,
								CachePolicyTransitioningClients,
								CachePolicyIsolatedCloudWorkstation,
								CachePolicyCollaboratingCloudWorkstation,
								CachePolicyReadOnlyHighVerificationTime,
							}, false),
						},
						auto_wan_optimize: {
							Type:     schema.TypeBool,
							Optional: true,
							Default:  true,
						},
						nfs_connection_multiplier: {
							Type:         schema.TypeInt,
							Optional:     true,
							Default:      DefaultNFSConnMult,
							ValidateFunc: validation.IntBetween(MinNFSConnMult, MaxNFSConnMult),
						},
						ordinal: {
							Type:     schema.TypeInt,
							Optional: true,
							Default:  0,
						},
						fixed_quota_percent: {
							Type:         schema.TypeInt,
							Optional:     true,
							Default:      0,
							ValidateFunc: validation.IntBetween(MinFixedQuotaPercent, MaxFixedQuotaPercent),
						},
						custom_settings: {
							Type:     schema.TypeSet,
							Optional: true,
							Elem: &schema.Schema{
								Type:         schema.TypeString,
								ValidateFunc: ValidateCustomSetting,
							},
							Set: schema.HashString,
						},
						junction: {
							Type:     schema.TypeSet,
							Optional: true,
							Elem: &schema.Resource{
								Schema: map[string]*schema.Schema{
									namespace_path: {
										Type:         schema.TypeString,
										Required:     true,
										ValidateFunc: validation.StringIsNotWhiteSpace,
									},
									cifs_share_name: {
										Type:         schema.TypeString,
										Optional:     true,
										Default:      "",
										ValidateFunc: ValidateCIFSShareName,
									},
									cifs_share_ace: {
										Type:         schema.TypeString,
										Optional:     true,
										Default:      AceDefault,
										ValidateFunc: ValidateCIFSShareAce,
									},
									core_filer_export: {
										Type:         schema.TypeString,
										Required:     true,
										ValidateFunc: validation.StringIsNotWhiteSpace,
									},
									export_subdirectory: {
										Type:         schema.TypeString,
										Optional:     true,
										Default:      "",
										ValidateFunc: ValidateExportSubdirectory,
									},
									export_rule: {
										Type:         schema.TypeString,
										Optional:     true,
										Default:      "",
										ValidateFunc: ValidateExportRule,
									},
								},
							},
						},
					},
				},
				Set: resourceAvereVfxtCoreFilerReferenceHash,
			},
			azure_storage_filer: {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Resource{
					Schema: map[string]*schema.Schema{
						account_name: {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: ValidateArmStorageAccountName,
						},
						container_name: {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: validate.StorageContainerName,
						},
						ordinal: {
							Type:     schema.TypeInt,
							Optional: true,
							Default:  0,
						},
						custom_settings: {
							Type:     schema.TypeSet,
							Optional: true,
							Elem: &schema.Schema{
								Type:         schema.TypeString,
								ValidateFunc: ValidateCustomSetting,
							},
							Set: schema.HashString,
						},
						junction_namespace_path: {
							Type:         schema.TypeString,
							Optional:     true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						cifs_share_name: {
							Type:         schema.TypeString,
							Optional:     true,
							Default:      "",
							ValidateFunc: ValidateCIFSShareName,
						},
						cifs_share_ace: {
							Type:         schema.TypeString,
							Optional:     true,
							Default:      AceDefault,
							ValidateFunc: ValidateCIFSShareAce,
						},
						export_rule: {
							Type:         schema.TypeString,
							Optional:     true,
							Default:      "",
							ValidateFunc: ValidateExportRule,
						},
					},
				},
				Set: resourceAvereVfxtAzureStorageCoreFilerReferenceHash,
			},
			vfxt_management_ip: {
				Type:     schema.TypeString,
				Computed: true,
			},
			vserver_ip_addresses: {
				Type:     schema.TypeList,
				Computed: true,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
			},
			node_names: {
				Type:     schema.TypeList,
				Computed: true,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
			},
			mass_filer_mappings: {
				Type:     schema.TypeList,
				Computed: true,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
			},
			primary_cluster_ips: {
				Type:     schema.TypeList,
				Computed: true,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
			},
			licensing_id: {
				Type:     schema.TypeString,
				Computed: true,
			},
		},
	}
}

func resourceVfxtCreate(d *schema.ResourceData, m interface{}) error {
	log.Printf("[INFO] [resourceVfxtCreate")
	defer log.Printf("[INFO] resourceVfxtCreate]")

	avereVfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if avereVfxt.RunLocal == false {
		if err := VerifySSHConnection(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, avereVfxt.SshPort); err != nil {
			return err
		}
	}

	//
	// The cluster will be created in the following order
	//  1. Cluster creation
	//  2. SetId() in Terraform to commit the cluster creation
	//  3. Timezone and DNS changes
	//  4. NTP Servers
	//  5. Global and Vserver Custom Support settings
	//  6. Users
	//  7. CIFS Settings
	//  8. Core Filers including custom settings
	//  9. Junctions
	// 10. Support Uploads if requested
	//

	if err := avereVfxt.Platform.CreateVfxt(avereVfxt); err != nil {
		return fmt.Errorf("failed to create cluster: %s\n", err)
	}

	d.Set(vfxt_management_ip, avereVfxt.ManagementIP)

	// the management ip will uniquely identify the cluster in the VNET
	d.SetId(avereVfxt.ManagementIP)

	if err := avereVfxt.CreateVServer(); err != nil {
		return fmt.Errorf("ERROR: error while creating VServer: %s", err)
	}

	if avereVfxt.Timezone != DefaultTimezone || len(avereVfxt.DnsServer) > 0 || len(avereVfxt.DnsDomain) > 0 || len(avereVfxt.DnsSearch) > 0 {
		if err := avereVfxt.UpdateCluster(); err != nil {
			return err
		}
	}

	if err := updateNtpServers(d, avereVfxt); err != nil {
		return err
	}

	if err := createGlobalSettings(d, avereVfxt); err != nil {
		return err
	}

	if err := createVServerSettings(d, avereVfxt); err != nil {
		return err
	}

	if err := createUsers(d, avereVfxt); err != nil {
		return err
	}

	if err := avereVfxt.EnableCIFS(); err != nil {
		return err
	}

	if avereVfxt.EnableExtendedGroups == true {
		if err := avereVfxt.ModifyExtendedGroups(); err != nil {
			return err
		}
	}

	// add the new filers
	existingCoreFilers := make(map[string]*CoreFiler)
	coreFilersToAdd, coreFilersToModify, err := getCoreFilersToAddorModify(d, existingCoreFilers, existingCoreFilers)
	if err != nil {
		return err
	}
	if err := createCoreFilers(coreFilersToAdd, avereVfxt); err != nil {
		return err
	}
	if err := modifyCoreFilers(coreFilersToModify, avereVfxt); err != nil {
		return err
	}

	existingAzureStorageFilers := make(map[string]*AzureStorageFiler)
	storageFilersToAdd, storageFilersToModify, err := getAzureStorageFilersToAddorModify(d, existingAzureStorageFilers, existingAzureStorageFilers)
	if err != nil {
		return err
	}
	if err := createAzureStorageFilers(storageFilersToAdd, avereVfxt); err != nil {
		return err
	}
	if err := modifyAzureStorageFilers(storageFilersToModify, avereVfxt); err != nil {
		return err
	}

	// add the new junctions
	if err := createJunctions(d, avereVfxt); err != nil {
		return err
	}

	// update the support
	if avereVfxt.EnableSupportUploads == true {
		if err := avereVfxt.ModifySupportUploads(); err != nil {
			return err
		}
	}

	return resourceVfxtRead(d, m)
}

func resourceVfxtRead(d *schema.ResourceData, m interface{}) error {
	log.Printf("[INFO] [resourceVfxtRead")
	defer log.Printf("[INFO] resourceVfxtRead]")

	avereVfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if avereVfxt.RunLocal == false {
		if err := VerifySSHConnection(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, avereVfxt.SshPort); err != nil {
			return err
		}
	}

	// return from read if the vfxt is not alive since it may be stop deallocated
	if !avereVfxt.IsAlive() {
		return fmt.Errorf("The vfxt management IP '%s' is not reachable.  Please confirm the cluster is alive and not stopped.", avereVfxt.ManagementIP)
	}

	currentVServerIPAddresses, err := avereVfxt.GetVServerIPAddresses()
	if err != nil {
		return fmt.Errorf("error encountered while getting vserver addresses '%v'", err)
	}
	avereVfxt.VServerIPAddresses = &currentVServerIPAddresses
	d.Set(vserver_ip_addresses, flattenStringSlice(avereVfxt.VServerIPAddresses))

	nodeNames, err := avereVfxt.GetNodes()
	if err != nil {
		return fmt.Errorf("error encountered getting nodes '%v'", err)
	}
	avereVfxt.NodeNames = &nodeNames
	d.Set(node_names, flattenStringSlice(avereVfxt.NodeNames))
	if len(*(avereVfxt.NodeNames)) >= MinNodesCount {
		d.Set(vfxt_node_count, len(*(avereVfxt.NodeNames)))
	}

	primaryIPs, err := avereVfxt.GetNodePrimaryIPs()
	if err != nil {
		return fmt.Errorf("error encountered getting nodes primary ips '%v'", err)
	}
	d.Set(primary_cluster_ips, flattenStringSlice(&primaryIPs))
	if len(*(avereVfxt.NodeNames)) >= MinNodesCount {
		d.Set(vfxt_node_count, len(*(avereVfxt.NodeNames)))
	}

	massMappings, err := avereVfxt.GetGenericFilerMappingList()
	if err != nil {
		return fmt.Errorf("error encountered getting the filer mappings '%v'", err)
	}
	d.Set(mass_filer_mappings, flattenStringSlice(&massMappings))

	cluster, err := avereVfxt.GetCluster()
	if err != nil {
		return fmt.Errorf("error encountered getting cluster '%v'", err)
	}
	d.Set(licensing_id, cluster.LicensingId)

	return nil
}

func resourceVfxtUpdate(d *schema.ResourceData, m interface{}) error {
	log.Printf("[INFO] [resourceVfxtUpdate")
	defer log.Printf("[INFO] resourceVfxtUpdate]")

	avereVfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if avereVfxt.RunLocal == false {
		if err := VerifySSHConnection(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, avereVfxt.SshPort); err != nil {
			return err
		}
	}

	// return from read if the vfxt is not alive since it may be stop deallocated
	if !avereVfxt.IsAlive() {
		return fmt.Errorf("The vfxt management IP '%s' is not reachable.  Please confirm the cluster is alive and not stopped.", avereVfxt.ManagementIP)
	}

	//
	// The cluster will be updated in the following order
	//  1. Timezone and DNS changes
	//  2. NTP Servers
	//  3. Global and Vserver Custom Support settings
	//  4. Update Users
	//  5. Delete Junctions
	//  6. Update CIFs
	//  7. Update Core Filers including Core Filer custom settings
	//  8. Add Junctions
	//  9. Update Extended Groups
	// 10. Scale cluster
	// 11. Update Support Uploads
	//

	if d.HasChange(timezone) || d.HasChange(dns_server) || d.HasChange(dns_domain) || d.HasChange(dns_search) {
		if err := avereVfxt.UpdateCluster(); err != nil {
			return err
		}
	}

	if d.HasChange(ntp_servers) {
		if err := updateNtpServers(d, avereVfxt); err != nil {
			return err
		}
	}

	if d.HasChange(global_custom_settings) {
		if err := deleteGlobalSettings(d, avereVfxt); err != nil {
			return err
		}
		if err := createGlobalSettings(d, avereVfxt); err != nil {
			return err
		}
	}

	if d.HasChange(vserver_settings) {
		if err := deleteVServerSettings(d, avereVfxt); err != nil {
			return err
		}
		if err := createVServerSettings(d, avereVfxt); err != nil {
			return err
		}
	}

	if d.HasChange(user) {
		if err := updateUsers(d, avereVfxt); err != nil {
			return err
		}
	}

	// update the core filers
	if d.HasChange(core_filer) || d.HasChange(azure_storage_filer) {
		existingCoreFilers, existingAzureStorageFilers, err := avereVfxt.GetExistingFilers()
		if err != nil {
			return err
		}
		coreFilersToDelete, err := getCoreFilersToDelete(d, existingCoreFilers)
		if err != nil {
			return err
		}
		storageFilersToDelete, err := getAzureStorageFilersToDelete(d, existingAzureStorageFilers)
		if err != nil {
			return err
		}
		junctionsToDelete, err := getJunctionsToDelete(d, avereVfxt, coreFilersToDelete, storageFilersToDelete)
		if err != nil {
			return err
		}
		coreFilersToAdd, coreFilersToModify, err := getCoreFilersToAddorModify(d, existingCoreFilers, coreFilersToDelete)
		if err != nil {
			return err
		}
		storageFilersToAdd, storageFilersToModify, err := getAzureStorageFilersToAddorModify(d, existingAzureStorageFilers, storageFilersToDelete)
		if err != nil {
			return err
		}
		if err := deleteJunctions(junctionsToDelete, avereVfxt); err != nil {
			return err
		}
		if err := deleteCoreFilers(coreFilersToDelete, avereVfxt); err != nil {
			return err
		}
		if err := deleteAzureStorageFilers(storageFilersToDelete, avereVfxt); err != nil {
			return err
		}

		if err := updateCifs(d, avereVfxt); err != nil {
			return err
		}

		if err := createCoreFilers(coreFilersToAdd, avereVfxt); err != nil {
			return err
		}
		if err := modifyCoreFilers(coreFilersToModify, avereVfxt); err != nil {
			return err
		}
		if err := createAzureStorageFilers(storageFilersToAdd, avereVfxt); err != nil {
			return err
		}
		if err := modifyAzureStorageFilers(storageFilersToModify, avereVfxt); err != nil {
			return err
		}

		// refresh all junctions, and add all missing
		if err := createJunctions(d, avereVfxt); err != nil {
			return err
		}
	} else {
		if err := updateCifs(d, avereVfxt); err != nil {
			return err
		}
	}

	if d.HasChange(enable_extended_groups) {
		if err := avereVfxt.ModifyExtendedGroups(); err != nil {
			return err
		}
	}

	// scale the cluster if node changed
	if d.HasChange(vfxt_node_count) {
		if err := scaleCluster(d, avereVfxt); err != nil {
			return err
		}
	}

	if d.HasChange(enable_support_uploads) {
		if err := avereVfxt.ModifySupportUploads(); err != nil {
			return err
		}
	}

	return resourceVfxtRead(d, m)
}

func resourceVfxtDelete(d *schema.ResourceData, m interface{}) error {
	log.Printf("[INFO] [resourceVfxtDelete")
	defer log.Printf("[INFO] resourceVfxtDelete]")

	avereVfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if avereVfxt.RunLocal == false {
		if err := VerifySSHConnection(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, avereVfxt.SshPort); err != nil {
			return err
		}
	}

	if err := avereVfxt.Platform.DestroyVfxt(avereVfxt); err != nil {
		return fmt.Errorf("failed to destroy cluster: %s\n", err)
	}

	d.Set(vfxt_management_ip, avereVfxt.ManagementIP)
	d.Set(vserver_ip_addresses, avereVfxt.VServerIPAddresses)
	d.Set(node_names, avereVfxt.NodeNames)

	// acknowledge deletion of the vfxt
	d.SetId("")

	return nil
}

func fillAvereVfxt(d *schema.ResourceData) (*AvereVfxt, error) {
	var err error
	var controllerAddress, controllerAdminUsername, controllerAdminPassword string
	var controllerSshPort int

	runLocal := d.Get(run_local).(bool)
	allowNonAscii := d.Get(allow_non_ascii).(bool)

	if !allowNonAscii {
		if err := validateSchemaforOnlyAscii(d); err != nil {
			return nil, err
		}
	}

	var authMethod ssh.AuthMethod
	if runLocal == false {
		if v, exists := d.GetOk(controller_address); exists {
			controllerAddress = v.(string)
		} else {
			return nil, fmt.Errorf("missing argument '%s'", controller_address)
		}
		if v, exists := d.GetOk(controller_admin_username); exists {
			controllerAdminUsername = v.(string)
		} else {
			return nil, fmt.Errorf("missing argument '%s'", controller_admin_username)
		}
		if v, exists := d.GetOk(controller_admin_password); exists {
			controllerAdminPassword = v.(string)
		}
		if v, exists := d.GetOk(controller_ssh_port); exists {
			controllerSshPort = v.(int)
		} else {
			controllerSshPort = DefaultSshPort
		}
		if len(controllerAdminPassword) > 0 {
			authMethod = GetPasswordAuthMethod(controllerAdminPassword)
		} else {
			authMethod, err = GetKeyFileAuthMethod()
			if err != nil {
				return nil, fmt.Errorf("failed to get key file: %s", err)
			}
		}
	}

	var iaasPlatform IaasPlatform
	platform := d.Get(platform).(string)
	switch platform {
	case PlatformAzure:
		if iaasPlatform, err = NewAzureIaasPlatform(d); err != nil {
			return nil, err
		}
	default:
		return nil, fmt.Errorf("platform '%s' not supported", platform)
	}

	var managementIP string
	if val, ok := d.Get(vfxt_management_ip).(string); ok {
		managementIP = val
	}
	vServerIPAddressesRaw := d.Get(vserver_ip_addresses).([]interface{})
	nodeNamesRaw := d.Get(node_names).([]interface{})

	nodeCount := d.Get(vfxt_node_count).(int)

	firstIPAddress := d.Get(vserver_first_ip).(string)
	ipAddressCount := d.Get(vserver_ip_count).(int)
	if nodeCount > ipAddressCount {
		ipAddressCount = nodeCount
	}
	lastIPAddress := ""
	if len(firstIPAddress) > 0 {
		if lastIPAddress, err = GetLastIPAddress(firstIPAddress, ipAddressCount); err != nil {
			return nil, err
		}
	}

	return NewAvereVfxt(
		controllerAddress,
		controllerAdminUsername,
		authMethod,
		controllerSshPort,
		runLocal,
		allowNonAscii,
		iaasPlatform,
		d.Get(vfxt_cluster_name).(string),
		d.Get(vfxt_admin_password).(string),
		d.Get(vfxt_ssh_key_data).(string),
		d.Get(enable_support_uploads).(bool),
		nodeCount,
		d.Get(node_size).(string),
		d.Get(node_cache_size).(int),
		firstIPAddress,
		lastIPAddress,
		d.Get(cifs_ad_domain).(string),
		d.Get(cifs_server_name).(string),
		d.Get(cifs_username).(string),
		d.Get(cifs_password).(string),
		d.Get(cifs_flatfile_passwd_uri).(string),
		d.Get(cifs_flatfile_group_uri).(string),
		d.Get(cifs_flatfile_passwd_b64z).(string),
		d.Get(cifs_flatfile_group_b64z).(string),
		d.Get(cifs_organizational_unit).(string),
		d.Get(enable_extended_groups).(bool),
		d.Get(user_assigned_managed_identity).(string),
		d.Get(ntp_servers).(string),
		d.Get(timezone).(string),
		d.Get(dns_server).(string),
		d.Get(dns_domain).(string),
		d.Get(dns_search).(string),
		d.Get(proxy_uri).(string),
		d.Get(cluster_proxy_uri).(string),
		d.Get(image_id).(string),
		managementIP,
		utils.ExpandStringSlice(vServerIPAddressesRaw),
		utils.ExpandStringSlice(nodeNamesRaw),
	), nil
}

func updateNtpServers(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	return avereVfxt.SetNtpServers(d.Get(ntp_servers).(string))
}

func createGlobalSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	for _, v := range d.Get(global_custom_settings).(*schema.Set).List() {
		if err := avereVfxt.CreateCustomSetting(v.(string), GetTerraformMessage(v.(string))); err != nil {
			return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", v.(string), err)
		}
	}
	return nil
}

func deleteGlobalSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	if d.HasChange(global_custom_settings) {
		old, new := d.GetChange(global_custom_settings)
		os := old.(*schema.Set)
		ns := new.(*schema.Set)

		removalList := os.Difference(ns)
		for _, v := range removalList.List() {
			if err := avereVfxt.RemoveCustomSetting(v.(string)); err != nil {
				return fmt.Errorf("ERROR: failed to remove custom setting '%s': %s", v.(string), err)
			}
		}
	}
	return nil
}

func createVServerSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	for _, v := range d.Get(vserver_settings).(*schema.Set).List() {
		if err := avereVfxt.CreateVServerSetting(v.(string)); err != nil {
			return fmt.Errorf("ERROR: failed to apply VServer setting '%s': %s", v.(string), err)
		}
	}
	return nil
}

func deleteVServerSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	if d.HasChange(vserver_settings) {
		old, new := d.GetChange(vserver_settings)
		os := old.(*schema.Set)
		ns := new.(*schema.Set)

		removalList := os.Difference(ns)
		for _, v := range removalList.List() {
			if err := avereVfxt.RemoveVServerSetting(v.(string)); err != nil {
				return fmt.Errorf("ERROR: failed to remove VServer setting '%s': %s", v.(string), err)
			}
		}
	}
	return nil
}

func createUsers(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	new := d.Get(user)
	newUsers, err := expandUsers(new.(*schema.Set).List())
	if err != nil {
		return err
	}
	return addUsers(newUsers, avereVfxt)
}

func updateUsers(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	if d.HasChange(user) {
		old, new := d.GetChange(user)
		oldUsers, err := expandUsers(old.(*schema.Set).List())
		if err != nil {
			return err
		}
		newUsers, err := expandUsers(new.(*schema.Set).List())
		if err != nil {
			return err
		}
		existingUsers, err := avereVfxt.ListNonAdminUsers()
		if err != nil {
			return err
		}

		removalList := make(map[string]*User)
		additionList := make(map[string]*User)

		// compare the old model to new
		for key, oldVal := range oldUsers {
			existingVal, existingOK := existingUsers[key]

			// check if user was removed and still exists
			if newVal, ok := newUsers[key]; !ok && existingOK {
				removalList[key] = oldVal
				// check if user was modified
			} else if ok && (!newVal.IsEqual(oldVal) || (existingOK && !newVal.IsEqualNoPassword(existingVal))) {
				if existingOK {
					removalList[key] = oldVal
				}
				additionList[key] = newVal
				// add if the user was missing
			} else if ok && !existingOK {
				additionList[key] = newVal
			}
		}

		// compare cluster existing to new
		for key, existingVal := range existingUsers {
			if _, oldOK := oldUsers[key]; oldOK {
				// this was in the model, and already evaluated
				continue
			}
			// check if the user exists on Avere and is removed in the model
			if newVal, ok := newUsers[key]; !ok {
				removalList[key] = existingVal

				// check if user exists on Avere and is modified from the model's values
			} else if !newVal.IsEqualNoPassword(existingVal) {
				removalList[key] = existingVal
				additionList[key] = newVal
			}
		}

		// find the new users
		for key, newVal := range newUsers {
			_, existingOK := existingUsers[key]

			if _, ok := oldUsers[key]; !ok && !existingOK {
				additionList[key] = newVal
			}
		}

		if err := removeUsers(removalList, avereVfxt); err != nil {
			return err
		}

		if err := addUsers(additionList, avereVfxt); err != nil {
			return err
		}
	}

	return nil
}

func addUsers(users map[string]*User, avereVfxt *AvereVfxt) error {
	for _, u := range users {
		if err := avereVfxt.AddUser(u); err != nil {
			return fmt.Errorf("ERROR: failed to add user'%s': %s", u.Name, err)
		}
	}
	return nil
}

func removeUsers(users map[string]*User, avereVfxt *AvereVfxt) error {
	for _, u := range users {
		if err := avereVfxt.RemoveUser(u); err != nil {
			return fmt.Errorf("ERROR: failed to remove user'%s': %s", u.Name, err)
		}
	}
	return nil
}

func getCoreFilersToDelete(d *schema.ResourceData, existingCoreFilers map[string]*CoreFiler) (results map[string]*CoreFiler, err error) {
	results = make(map[string]*CoreFiler)
	new := d.Get(core_filer)
	newFilers, err := expandCoreFilers(new.(*schema.Set).List())
	if err != nil {
		return results, err
	}

	// any removed filers or filers with changed fqdn
	for k, v := range existingCoreFilers {
		n, ok := newFilers[k]
		if ok && n.FqdnOrPrimaryIp == v.FqdnOrPrimaryIp && n.CachePolicy == v.CachePolicy {
			// no change to the existing filer
			continue
		}
		results[k] = v
	}
	return results, err
}

func deleteCoreFilers(coreFilersToDelete map[string]*CoreFiler, averevfxt *AvereVfxt) error {
	for k := range coreFilersToDelete {
		if err := averevfxt.DeleteFiler(k); err != nil {
			return err
		}
	}
	return nil
}

func getAzureStorageFilersToDelete(d *schema.ResourceData, existingAzureStorageFilers map[string]*AzureStorageFiler) (results map[string]*AzureStorageFiler, err error) {
	results = make(map[string]*AzureStorageFiler)
	new := d.Get(azure_storage_filer)
	newAzureStorageFilers, err := expandAzureStorageFilers(new.(*schema.Set).List())
	if err != nil {
		return results, err
	}

	// delete any removed azure storage filers
	for k, v := range existingAzureStorageFilers {
		n, ok := newAzureStorageFilers[k]
		if ok && n.Container == v.Container {
			// no change to existing storage filer
			continue
		}
		results[k] = v
	}
	return results, nil
}

func deleteAzureStorageFilers(azureStorageFilersToDelete map[string]*AzureStorageFiler, averevfxt *AvereVfxt) error {
	for k, v := range azureStorageFilersToDelete {
		if err := averevfxt.DeleteFiler(k); err != nil {
			return err
		}
		if err := averevfxt.DeleteAzureStorageCredentials(v); err != nil {
			return err
		}
	}
	return nil
}

func getJunctionsToDelete(d *schema.ResourceData, averevfxt *AvereVfxt, coreFilersToDelete map[string]*CoreFiler, storageFilersToDelete map[string]*AzureStorageFiler) (results map[string]*Junction, err error) {
	log.Printf("[INFO] [getJunctionsToDelete")
	defer log.Printf("[INFO] getJunctionsToDelete]")
	results = make(map[string]*Junction)
	newJunctions, err := expandAllJunctions(d)
	if err != nil {
		return results, err
	}

	// get the map of existing junctions
	existingJunctions, err := averevfxt.GetExistingJunctions()
	if err != nil {
		return results, err
	}

	// delete any removed or updated junctions
	for k, existingJunction := range existingJunctions {
		newJunction, ok := newJunctions[k]
		_, deleteCoreFiler := coreFilersToDelete[existingJunction.CoreFilerName]
		_, deleteStorageFiler := storageFilersToDelete[existingJunction.CoreFilerName]
		if ok && newJunction.IsEqual(existingJunction) && !deleteCoreFiler && !deleteStorageFiler {
			// the junction and the core file to which is belongs is not being deleted
			continue
		}
		results[k] = existingJunction
	}
	return results, nil
}

func deleteJunctions(junctionsToDelete map[string]*Junction, averevfxt *AvereVfxt) error {
	for _, j := range junctionsToDelete {
		if len(j.CifsShareName) > 0 {
			if err := averevfxt.DeleteCifsShare(j.CifsShareName); err != nil {
				return err
			}
		}
		if err := averevfxt.DeleteJunction(j.NameSpacePath); err != nil {
			return err
		}
	}
	return nil
}

func getCoreFilersToAddorModify(d *schema.ResourceData, existingCoreFilers map[string]*CoreFiler, coreFilersToDelete map[string]*CoreFiler) (addResults map[string]*CoreFiler, modifyResults map[string]*CoreFiler, err error) {
	log.Printf("[INFO] [getCoreFilersToAddorModify")
	defer log.Printf("[INFO] getCoreFilersToAddorModify]")
	addResults = make(map[string]*CoreFiler)
	modifyResults = make(map[string]*CoreFiler)
	// get the core filers from the model
	new := d.Get(core_filer)
	newFilers, err := expandCoreFilers(new.(*schema.Set).List())
	if err != nil {
		return addResults, modifyResults, err
	}

	// add any new filers
	for k, v := range newFilers {
		_, existingFiler := existingCoreFilers[k]
		_, deletedFiler := coreFilersToDelete[k]
		if !existingFiler || deletedFiler {
			addResults[k] = v
		} else {
			modifyResults[k] = v
		}
	}
	return addResults, modifyResults, nil
}

func createCoreFilers(coreFilersToAdd map[string]*CoreFiler, averevfxt *AvereVfxt) error {
	corefilers := make([]*CoreFiler, 0, len(coreFilersToAdd))
	for _, v := range coreFilersToAdd {
		corefilers = append(corefilers, v)
	}

	// sort the CoreFiler slice by ordinal and name
	sort.Slice(corefilers, func(i, j int) bool {
		if corefilers[i].Ordinal == corefilers[j].Ordinal {
			return corefilers[i].Name < corefilers[j].Name
		}
		return corefilers[i].Ordinal < corefilers[j].Ordinal
	})

	isFixedQuotaRequired, err := isFixedQuotaRequired(corefilers, averevfxt)
	if err != nil {
		return err
	}

	if isFixedQuotaRequired {
		if err = addCoreFilersWithBalancedQuota(corefilers, averevfxt); err != nil {
			return err
		}
	} else {
		if err = addCoreFilersWithNoBalancedQuota(corefilers, averevfxt); err != nil {
			return err
		}
	}

	return nil
}

func isFixedQuotaRequired(corefilers []*CoreFiler, averevfxt *AvereVfxt) (bool, error) {
	// ignore fixed quota for 1 or less corefilers
	if len(corefilers) <= 1 {
		return false, nil
	}

	// only balance quota when starting with no core filers
	coreFilers, err := averevfxt.GetExistingFilerNames()
	if err != nil {
		return false, err
	}
	if len(coreFilers) > 0 {
		return false, nil
	}

	for _, v := range corefilers {
		if v.FixedQuotaPercent > MinFixedQuotaPercent {
			return true, nil
		}
	}
	return false, nil
}

// add the core filers and custom settings without balancing quota
func addCoreFilersWithBalancedQuota(corefilers []*CoreFiler, averevfxt *AvereVfxt) error {
	log.Printf("[INFO] [addCoreFilerWithBalancedQuota")
	defer log.Printf("[INFO] addCoreFilerWithBalancedQuota]")

	var lastCoreFiler *CoreFiler
	lastIndex := len(corefilers)

	// increase speed of dynamic block allocation
	if err := startFixedQuotaPercent(corefilers, averevfxt); err != nil {
		return fmt.Errorf("error encountered while starting setting of fixed quota: %v", err)
	}

	// There is an undesired behavior in Avere vFXT where the first core filer is added and
	// it receives all the quota space.  To speed up balancing, add the last core filer, and
	// then delete it after added the other core filers.  This releases the space.
	if QuotaSpeedUpDeleteFirstFiler {
		lastIndex = lastIndex - 1
		lastCoreFiler = corefilers[lastIndex]
		log.Printf("[INFO] add last core filer '%s'", lastCoreFiler.Name)
		if err := createCoreFilerWithFixedQuota(lastCoreFiler, averevfxt); err != nil {
			return err
		}
	}

	// add the core filer and quota percent first (not adding last core filer if used for quota speedup)
	for i := 0; i < lastIndex; i++ {
		if err := createCoreFilerWithFixedQuota(corefilers[i], averevfxt); err != nil {
			return err
		}
	}

	// remove and add the last core filer and quota percent, to release the space, and speed allocation
	if QuotaSpeedUpDeleteFirstFiler {
		log.Printf("[INFO] remove last core filer '%s'", lastCoreFiler.Name)
		if err := averevfxt.DeleteFiler(lastCoreFiler.Name); err != nil {
			return err
		}

		log.Printf("[INFO] add last core filer '%s'", lastCoreFiler.Name)
		if err := createCoreFilerWithFixedQuota(lastCoreFiler, averevfxt); err != nil {
			return err
		}
	}

	// add the custom settings, after core filers and fixed quota percent has been added
	// the custom settings are added after all core filers are added because they are slow to add,
	// and could slow down the rebalancing
	if err := addCustomSettings(corefilers, averevfxt); err != nil {
		return err
	}

	// restore speed of dynamic block allocation and remove all cpolicyActive settings
	if err := finishFixedQuotaPercent(corefilers, averevfxt); err != nil {
		return fmt.Errorf("error encountered while starting setting of fixed quota: %v", err)
	}

	return nil
}

// add the core filers and custom settings without balancing quota
func addCoreFilersWithNoBalancedQuota(corefilers []*CoreFiler, averevfxt *AvereVfxt) error {
	log.Printf("[INFO] [addCoreFilerWithNoBalancedQuota")
	defer log.Printf("[INFO] addCoreFilerWithNoBalancedQuota]")

	for i := 0; i < len(corefilers); i++ {
		if err := averevfxt.CreateCoreFiler(corefilers[i]); err != nil {
			return err
		}
	}

	if err := addCustomSettings(corefilers, averevfxt); err != nil {
		return err
	}
	return nil
}

func addCustomSettings(corefilers []*CoreFiler, averevfxt *AvereVfxt) error {
	for _, v := range corefilers {
		if err := averevfxt.AddCoreFilerCustomSettings(v); err != nil {
			return err
		}
	}
	return nil
}

func createCoreFilerWithFixedQuota(coreFiler *CoreFiler, averevfxt *AvereVfxt) error {
	if err := averevfxt.CreateCoreFiler(coreFiler); err != nil {
		return err
	}
	if coreFiler.FixedQuotaPercent > MinFixedQuotaPercent {
		if err := averevfxt.SetFixedQuotaPercent(coreFiler.Name, coreFiler.FixedQuotaPercent); err != nil {
			return err
		}
	}
	return nil
}

func startFixedQuotaPercent(corefilers []*CoreFiler, averevfxt *AvereVfxt) error {

	if err := averevfxt.CreateCustomSetting(QuotaCacheMoveMax, TerraformFeatureMessage); err != nil {
		return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", QuotaCacheMoveMax, err)
	}

	smallestQuota := getSmallestQuotaPercent(corefilers)
	divisorFloorSetting := fmt.Sprintf(QuotaDivisorFloor, smallestQuota)
	if err := averevfxt.CreateCustomSetting(divisorFloorSetting, TerraformFeatureMessage); err != nil {
		return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", divisorFloorSetting, err)
	}

	if err := averevfxt.CreateCustomSetting(QuotaMaxMultiplierForInvalidatedMassQuota, TerraformFeatureMessage); err != nil {
		return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", QuotaMaxMultiplierForInvalidatedMassQuota, err)
	}

	return nil
}

func getSmallestQuotaPercent(corefilers []*CoreFiler) int {
	result := MaxFixedQuotaPercent
	for _, v := range corefilers {
		if v.FixedQuotaPercent > MinFixedQuotaPercent && v.FixedQuotaPercent < result {
			result = v.FixedQuotaPercent
		}
	}
	return result
}

func finishFixedQuotaPercent(corefilers []*CoreFiler, averevfxt *AvereVfxt) error {
	// wait QuotaWaitMinutes or until until the core filers are in the correct range
	startTime := time.Now()
	durationQuotaWaitMinutes := time.Duration(QuotaWaitMinutes) * time.Minute
	for time.Since(startTime) < durationQuotaWaitMinutes {
		time.Sleep(30 * time.Second)
		if withinRange(corefilers, averevfxt) {
			log.Printf("[INFO] all core filers within correct quota range")
			break
		}
	}

	// remove each of the cpolicyActive custom settings
	for _, v := range corefilers {
		if v.FixedQuotaPercent > MinFixedQuotaPercent {
			averevfxt.RemoveFixedQuotaPercent(v.Name, v.FixedQuotaPercent)
		}
	}

	if err := averevfxt.RemoveCustomSetting(QuotaCacheMoveMax); err != nil {
		return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", QuotaCacheMoveMax, err)
	}
	if err := averevfxt.RemoveCustomSetting(QuotaDivisorFloor); err != nil {
		return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", QuotaDivisorFloor, err)
	}
	if err := averevfxt.RemoveCustomSetting(QuotaMaxMultiplierForInvalidatedMassQuota); err != nil {
		return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", QuotaMaxMultiplierForInvalidatedMassQuota, err)
	}

	return nil
}

func withinRange(corefilers []*CoreFiler, averevfxt *AvereVfxt) bool {
	percentageMap, err := averevfxt.GetCoreFilerSpacePercentage()
	if err != nil {
		log.Printf("[WARN] error encountered getting core filer space percentage: %v", err)
		return false
	}

	for _, v := range corefilers {
		clusterPct, ok := percentageMap[v.Name]
		if !ok {
			log.Printf("[WARN] missing key %s: corefilers %v, pmap %v", v.Name, corefilers, percentageMap)
			return false
		}
		if v.FixedQuotaPercent > MinFixedQuotaPercent {
			targetPercentage := float32(v.FixedQuotaPercent) / 100.0
			minTargetPercentageError := targetPercentage - TargetPercentageError
			if clusterPct < minTargetPercentageError {
				log.Printf("[INFO] %s not yet within range: corefilers %v, pmap %v", v.Name, corefilers, percentageMap)
				return false
			}
		}
	}

	return true
}

func modifyCoreFilers(coreFilersToModify map[string]*CoreFiler, averevfxt *AvereVfxt) error {
	for _, v := range coreFilersToModify {
		if err := averevfxt.RemoveCoreFilerCustomSettings(v); err != nil {
			return err
		}
		if err := averevfxt.AddCoreFilerCustomSettings(v); err != nil {
			return err
		}
	}
	return nil
}

func getAzureStorageFilersToAddorModify(d *schema.ResourceData, existingAzureStorageFilers map[string]*AzureStorageFiler, storageFilersToDelete map[string]*AzureStorageFiler) (addResults map[string]*AzureStorageFiler, modifyResults map[string]*AzureStorageFiler, err error) {
	addResults = make(map[string]*AzureStorageFiler)
	modifyResults = make(map[string]*AzureStorageFiler)
	// get the storage filers from the model
	new := d.Get(azure_storage_filer)
	newAzureStorageFilers, err := expandAzureStorageFilers(new.(*schema.Set).List())
	if err != nil {
		return addResults, modifyResults, err
	}

	// add any new filers
	for k, v := range newAzureStorageFilers {
		_, existingFiler := existingAzureStorageFilers[k]
		_, deletedFiler := storageFilersToDelete[k]
		if !existingFiler || deletedFiler {
			addResults[k] = v
		} else {
			modifyResults[k] = v
		}
	}
	return addResults, modifyResults, nil
}

func createAzureStorageFilers(storageFilersToAdd map[string]*AzureStorageFiler, averevfxt *AvereVfxt) error {
	storagefilers := make([]*AzureStorageFiler, 0, len(storageFilersToAdd))
	for _, v := range storageFilersToAdd {
		storagefilers = append(storagefilers, v)
	}

	// sort the CoreFiler slice by ordinal and name
	sort.Slice(storagefilers, func(i, j int) bool {
		if storagefilers[i].Ordinal == storagefilers[j].Ordinal {
			return storagefilers[i].GetCloudFilerName() < storagefilers[j].GetCloudFilerName()
		}
		return storagefilers[i].Ordinal < storagefilers[j].Ordinal
	})

	for _, v := range storagefilers {
		if err := averevfxt.CreateAzureStorageFiler(v); err != nil {
			return err
		}
		if err := averevfxt.AddStorageFilerCustomSettings(v); err != nil {
			return err
		}
	}
	return nil
}

func modifyAzureStorageFilers(storageFilersToModify map[string]*AzureStorageFiler, averevfxt *AvereVfxt) error {
	for _, v := range storageFilersToModify {
		if err := averevfxt.RemoveStorageFilerCustomSettings(v); err != nil {
			return err
		}
		if err := averevfxt.AddStorageFilerCustomSettings(v); err != nil {
			return err
		}
	}
	return nil
}

func junctionsRequireCifs(junctions map[string]*Junction) bool {
	for _, v := range junctions {
		if len(v.CifsShareName) > 0 {
			return true
		}
	}
	return false
}

func createJunctions(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	newJunctions, err := expandAllJunctions(d)
	if err != nil {
		return err
	}

	if junctionsRequireCifs(newJunctions) && !averevfxt.CIFSSettingsExist() {
		return fmt.Errorf("one or more junctions requests a cifs share, but cifs not enabled")
	}

	// get the map of existing junctions
	existingJunctions, err := averevfxt.GetExistingJunctions()
	if err != nil {
		return err
	}

	// add any new junctions
	for k, v := range newJunctions {
		if _, ok := existingJunctions[k]; ok {
			// the junction exists, and we know from deletion they are the same
			continue
		}
		if err := averevfxt.CreateJunction(v); err != nil {
			return err
		}
	}
	return nil
}

func updateCifs(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	// CIFS must be updated after the last possible CIF shares have been removed, but
	// before new shares are added
	if d.HasChange(cifs_ad_domain) ||
		d.HasChange(cifs_server_name) ||
		d.HasChange(cifs_username) ||
		d.HasChange(cifs_password) ||
		d.HasChange(cifs_flatfile_passwd_uri) ||
		d.HasChange(cifs_flatfile_group_uri) ||
		d.HasChange(cifs_flatfile_passwd_b64z) ||
		d.HasChange(cifs_flatfile_group_b64z) ||
		d.HasChange(cifs_organizational_unit) {
		if err := averevfxt.DisableCIFS(); err != nil {
			return err
		}
		if err := averevfxt.EnableCIFS(); err != nil {
			return err
		}
	}
	return nil
}

func scaleCluster(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	oldRaw, newRaw := d.GetChange(vfxt_node_count)
	previousCount := oldRaw.(int)
	newCount := newRaw.(int)
	if err := averevfxt.ScaleCluster(previousCount, newCount); err != nil {
		return err
	}
	return nil
}

func expandUsers(l []interface{}) (map[string]*User, error) {
	results := make(map[string]*User)
	for _, v := range l {
		input := v.(map[string]interface{})
		name := input[name].(string)
		password := input[password].(string)
		permission := input[permission].(string)

		// verify no duplicates
		if _, ok := results[name]; ok {
			return nil, fmt.Errorf("Error: two or more admin users share the same key '%s'", name)
		}

		user := &User{
			Name:       name,
			Password:   password,
			Permission: permission,
		}

		results[name] = user
	}
	return results, nil
}

func expandCoreFilers(l []interface{}) (map[string]*CoreFiler, error) {
	results := make(map[string]*CoreFiler)

	totalFixedQuotaPercent := MinFixedQuotaPercent

	for _, v := range l {
		input := v.(map[string]interface{})

		// get the properties
		name := input[core_filer_name].(string)
		fqdnOrPrimaryIp := input[fqdn_or_primary_ip].(string)
		cachePolicy := input[cache_policy].(string)
		autoWanOptimize := input[auto_wan_optimize].(bool)
		nfsConnectionMultiplier := input[nfs_connection_multiplier].(int)
		ordinal := input[ordinal].(int)
		fixedQuotaPercent := input[fixed_quota_percent].(int)
		customSettingsRaw := input[custom_settings].(*schema.Set).List()
		customSettings := make([]*CustomSetting, len(customSettingsRaw), len(customSettingsRaw))
		for i, v := range customSettingsRaw {
			customSettings[i] = InitializeCustomSetting(v.(string))
		}
		// verify no duplicates
		if _, ok := results[name]; ok {
			return nil, fmt.Errorf("Error: two or more core filers share the same key '%s'", name)
		}
		// verify haven't exceeded fixed quota percent
		totalFixedQuotaPercent += fixedQuotaPercent
		if totalFixedQuotaPercent > MaxFixedQuotaPercent {
			return nil, fmt.Errorf("the sum of fixed_quota_percent on the core filer exceeds 100")
		}

		// add to map
		output := &CoreFiler{
			Name:                    name,
			FqdnOrPrimaryIp:         fqdnOrPrimaryIp,
			CachePolicy:             cachePolicy,
			AutoWanOptimize:         autoWanOptimize,
			NfsConnectionMultiplier: nfsConnectionMultiplier,
			Ordinal:                 ordinal,
			FixedQuotaPercent:       fixedQuotaPercent,
			CustomSettings:          customSettings,
		}
		results[name] = output
	}
	return results, nil
}

func expandAzureStorageFilers(l []interface{}) (map[string]*AzureStorageFiler, error) {
	results := make(map[string]*AzureStorageFiler)
	for _, v := range l {
		input := v.(map[string]interface{})

		// get the properties
		name := input[account_name].(string)
		container := input[container_name].(string)
		ordinal := input[ordinal].(int)
		customSettingsRaw := input[custom_settings].(*schema.Set).List()
		customSettings := make([]*CustomSetting, len(customSettingsRaw), len(customSettingsRaw))
		for i, v := range customSettingsRaw {
			customSettings[i] = InitializeCustomSetting(v.(string))
		}

		// add to map
		output := &AzureStorageFiler{
			AccountName:    name,
			Container:      container,
			Ordinal:        ordinal,
			CustomSettings: customSettings,
		}
		// verify no duplicates
		if _, ok := results[output.GetCloudFilerName()]; ok {
			return nil, fmt.Errorf("Error: two or more azure storage filers share the same key '%s'", name)
		}
		results[output.GetCloudFilerName()] = output
	}
	return results, nil
}

func expandAllJunctions(d *schema.ResourceData) (map[string]*Junction, error) {
	newJunctions := make(map[string]*Junction)

	coreFilers := d.Get(core_filer)
	if err := expandCoreFilerJunctions(coreFilers.(*schema.Set).List(), newJunctions); err != nil {
		return nil, err
	}

	storageCoreFilers := d.Get(azure_storage_filer)
	if err := expandAzureStorageFilerJunctions(storageCoreFilers.(*schema.Set).List(), newJunctions); err != nil {
		return nil, err
	}
	return newJunctions, nil
}

func expandCoreFilerJunctions(l []interface{}, results map[string]*Junction) error {
	for _, v := range l {
		input := v.(map[string]interface{})
		coreFilerName := input[core_filer_name].(string)
		junctions := input[junction].(*schema.Set).List()
		for _, jv := range junctions {
			junctionRaw := jv.(map[string]interface{})
			junction, err := NewJunction(
				junctionRaw[namespace_path].(string),
				coreFilerName,
				junctionRaw[core_filer_export].(string),
				junctionRaw[export_subdirectory].(string),
				PermissionsPreserve,
				junctionRaw[export_rule].(string),
				junctionRaw[cifs_share_name].(string),
				junctionRaw[cifs_share_ace].(string))
			if err != nil {
				return err
			}
			// verify no duplicates
			if _, ok := results[junction.NameSpacePath]; ok {
				return fmt.Errorf("Error: two or more junctions share the same namespace_path '%s'", junction.NameSpacePath)
			}
			results[junction.NameSpacePath] = junction
		}
	}
	return nil
}

func expandAzureStorageFilerJunctions(l []interface{}, results map[string]*Junction) error {
	for _, v := range l {
		input := v.(map[string]interface{})
		storageName := input[account_name].(string)
		containerName := input[container_name].(string)
		cloudFilerName := GetCloudFilerName(storageName, containerName)
		junction, err := NewJunction(
			input[junction_namespace_path].(string),
			cloudFilerName,
			CloudFilerExport,
			"",
			PermissionsModebits,
			input[export_rule].(string),
			input[cifs_share_name].(string),
			input[cifs_share_ace].(string))
		if err != nil {
			return err
		}
		// verify no duplicates
		if _, ok := results[junction.NameSpacePath]; ok {
			return fmt.Errorf("Error: two or more junctions share the same namespace_path '%s'", junction.NameSpacePath)
		}
		results[junction.NameSpacePath] = junction
	}
	return nil
}

func resourceAvereUserReferenceHash(v interface{}) int {
	var buf bytes.Buffer
	if m, ok := v.(map[string]interface{}); ok {
		if v, ok := m[name]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
	}
	return hashcode.String(buf.String())
}

func resourceAvereVfxtCoreFilerReferenceHash(v interface{}) int {
	var buf bytes.Buffer

	if m, ok := v.(map[string]interface{}); ok {
		if v, ok := m[core_filer_name]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[fqdn_or_primary_ip]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[cache_policy]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[auto_wan_optimize]; ok {
			buf.WriteString(fmt.Sprintf("%v;", v.(bool)))
		}
		if v, ok := m[nfs_connection_multiplier]; ok {
			buf.WriteString(fmt.Sprintf("%v;", v.(int)))
		}
		if v, ok := m[ordinal]; ok {
			buf.WriteString(fmt.Sprintf("%d;", v.(int)))
		}
		if v, ok := m[custom_settings]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(*schema.Set).List()))
		}
		if v, ok := m[junction].(*schema.Set); ok {
			for _, j := range v.List() {
				if m, ok := j.(map[string]interface{}); ok {
					if v2, ok := m[namespace_path]; ok {
						buf.WriteString(fmt.Sprintf("%s;", v2.(string)))
					}
					if v2, ok := m[core_filer_export]; ok {
						buf.WriteString(fmt.Sprintf("%s;", v2.(string)))
					}
					if v2, ok := m[export_subdirectory]; ok {
						buf.WriteString(fmt.Sprintf("%s;", v2.(string)))
					}
					if v2, ok := m[export_rule]; ok {
						buf.WriteString(fmt.Sprintf("%s;", v2.(string)))
					}
					if v2, ok := m[cifs_share_name]; ok {
						buf.WriteString(fmt.Sprintf("%s;", v2.(string)))
					}
					if v2, ok := m[cifs_share_ace]; ok {
						buf.WriteString(fmt.Sprintf("%s;", v2.(string)))
					}
				}
			}
		}
	}
	return hashcode.String(buf.String())
}

func resourceAvereVfxtAzureStorageCoreFilerReferenceHash(v interface{}) int {
	var buf bytes.Buffer

	if m, ok := v.(map[string]interface{}); ok {
		if v, ok := m[account_name]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[container_name]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[ordinal]; ok {
			buf.WriteString(fmt.Sprintf("%d;", v.(int)))
		}
		if v, ok := m[custom_settings]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(*schema.Set).List()))
		}
		if v, ok := m[junction_namespace_path]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[export_rule]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[cifs_share_name]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
		if v, ok := m[cifs_share_ace]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
	}
	return hashcode.String(buf.String())
}

func validateSchemaforOnlyAscii(d *schema.ResourceData) error {
	validateParameterSlice := []string{
		controller_address,
		controller_admin_username,
		controller_admin_password,
		location,
		azure_resource_group,
		azure_network_resource_group,
		azure_network_name,
		azure_subnet_name,
		ntp_servers,
		timezone,
		dns_server,
		dns_domain,
		dns_search,
		proxy_uri,
		cluster_proxy_uri,
		image_id,
		vfxt_cluster_name,
		vfxt_admin_password,
		vfxt_ssh_key_data,
		user_assigned_managed_identity,
	}

	for _, parameter := range validateParameterSlice {
		if v, exists := d.GetOk(parameter); exists {
			if err := ValidateOnlyAscii(v.(string), parameter); err != nil {
				return err
			}
		}
	}

	validateListParameterSlice := []string{
		global_custom_settings,
		vserver_settings,
	}

	for _, listName := range validateListParameterSlice {
		for _, v := range d.Get(listName).(*schema.Set).List() {
			if err := ValidateOnlyAscii(v.(string), fmt.Sprintf("%s-'%s'", listName, v.(string))); err != nil {
				return err
			}
		}
	}

	// user parameters do not need ascii check since they have custom validation functions

	for _, v := range d.Get(core_filer).(*schema.Set).List() {
		input := v.(map[string]interface{})
		corefilerSlice := []string{
			input[core_filer_name].(string),
			input[fqdn_or_primary_ip].(string),
			input[cache_policy].(string),
		}
		for _, parameter := range corefilerSlice {
			if err := ValidateOnlyAscii(parameter, parameter); err != nil {
				return err
			}
		}
		for _, v := range input[custom_settings].(*schema.Set).List() {
			if err := ValidateOnlyAscii(v.(string), fmt.Sprintf("%s-customsetting-'%s'", core_filer_name, v.(string))); err != nil {
				return err
			}
		}
		// the junction
		if v, ok := input[junction].(*schema.Set); ok {
			for _, j := range v.List() {
				if m, ok := j.(map[string]interface{}); ok {
					if v2, ok := m[namespace_path]; ok {
						if err := ValidateOnlyAscii(v2.(string), fmt.Sprintf("%s-'%s'", namespace_path, v2.(string))); err != nil {
							return err
						}
					}
					if v2, ok := m[core_filer_export]; ok {
						if err := ValidateOnlyAscii(v2.(string), fmt.Sprintf("%s-'%s'", core_filer_name, v2.(string))); err != nil {
							return err
						}
					}
					if v2, ok := m[export_subdirectory]; ok {
						if err := ValidateOnlyAscii(v2.(string), fmt.Sprintf("%s-'%s'", export_subdirectory, v2.(string))); err != nil {
							return err
						}
					}
					if v2, ok := m[export_rule]; ok {
						if err := ValidateOnlyAscii(v2.(string), fmt.Sprintf("%s-'%s'", export_rule, v2.(string))); err != nil {
							return err
						}
					}
					if v2, ok := m[cifs_share_name]; ok {
						if err := ValidateOnlyAscii(v2.(string), fmt.Sprintf("%s-'%s'", cifs_share_name, v2.(string))); err != nil {
							return err
						}
					}
					if v2, ok := m[cifs_share_ace]; ok {
						if err := ValidateOnlyAscii(v2.(string), fmt.Sprintf("%s-'%s'", cifs_share_ace, v2.(string))); err != nil {
							return err
						}
					}
				}
			}
		}
	}

	// storage filers
	for _, v := range d.Get(azure_storage_filer).(*schema.Set).List() {
		input := v.(map[string]interface{})
		storagefilerSlice := []string{
			input[account_name].(string),
			input[container_name].(string),
			input[export_rule].(string),
			input[cifs_share_name].(string),
			input[cifs_share_ace].(string),
		}
		// the junction namespace path is optional, and has no default
		if v, ok := input[junction_namespace_path]; ok {
			storagefilerSlice = append(storagefilerSlice, v.(string))
		}
		for _, parameter := range storagefilerSlice {
			if err := ValidateOnlyAscii(parameter, parameter); err != nil {
				return err
			}
		}
		for _, v := range input[custom_settings].(*schema.Set).List() {
			if err := ValidateOnlyAscii(v.(string), fmt.Sprintf("%s-customsetting-'%s'", input[account_name].(string), v.(string))); err != nil {
				return err
			}
		}
	}

	return nil
}

// from "github.com/terraform-providers/terraform-provider-azurerm/azurerm/internal/services/storage"
func ValidateArmStorageAccountName(v interface{}, _ string) (warnings []string, errors []error) {
	input := v.(string)

	if !regexp.MustCompile(`\A([a-z0-9]{3,24})\z`).MatchString(input) {
		errors = append(errors, fmt.Errorf("name (%q) can only consist of lowercase letters and numbers, and must be between 3 and 24 characters long", input))
	}

	return warnings, errors
}

func ValidateExportSubdirectory(v interface{}, _ string) (warnings []string, errors []error) {
	input := v.(string)

	if len(input) > 0 && !regexp.MustCompile(`^[^\/]`).MatchString(input) {
		errors = append(errors, fmt.Errorf("%s (%s) must not begin with a '/'", export_subdirectory, input))
	}

	return warnings, errors
}

func ValidateExportRule(v interface{}, _ string) (warnings []string, errors []error) {
	input := v.(string)

	if len(input) > 0 {
		if _, err := ParseExportRules(input); err != nil {
			errors = append(errors, err)
		}
	}

	return warnings, errors
}

func ValidateUserName(v interface{}, _ string) (warnings []string, errors []error) {
	input := v.(string)

	if input == AdminUserName {
		errors = append(errors, fmt.Errorf("the name specified for user must not be reserved user '%s'", AdminUserName))
	}

	if !regexp.MustCompile(`^[0-9a-zA-Z]{1,60}$`).MatchString(input) {
		errors = append(errors, fmt.Errorf("the user name '%s' is invalid, and may only alphanumeric characters and be 1 to 60 characters in length", input))
	}

	return warnings, errors
}

func ValidateVfxtName(v interface{}, _ string) (warnings []string, errors []error) {
	input := v.(string)

	if !regexp.MustCompile(`^[a-z]([-a-z0-9]*[a-z0-9])?$`).MatchString(input) {
		errors = append(errors, fmt.Errorf("the vfxt name '%s' is invalid, and per vfxt.py must match the regular expression ^[a-z]([-a-z0-9]*[a-z0-9])?$ ''", input))
	}

	return warnings, errors
}

func ValidateCustomSetting(v interface{}, _ string) (warnings []string, errors []error) {
	customSetting := v.(string)

	if err := ValidateCustomSettingFormat(customSetting); err != nil {
		errors = append(errors, err)
	}

	if ok, err := IsCustomSettingDeprecated(customSetting); ok {
		errors = append(errors, err)
	}

	return warnings, errors
}

func ValidateSSHKey(v interface{}, _ string) (warnings []string, errors []error) {
	input := v.(string)

	// vfxt.py requires the following ssh key format, otherwise during deploy clusters fail to communicate
	// and shows up as a failure in the vfxt node /var/log/messages as "Host key verification failed."
	// regex from https://gist.github.com/paranoiq/1932126
	if !regexp.MustCompile(`^ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3} ([^@]+@[^@]+)$`).MatchString(input) {
		errors = append(errors, fmt.Errorf("the ssh key '%s' is invalid.  It must have 3 parts and match the regular expression '^ssh-rsa AAAA[0-9A-Za-z+/]+[=]{0,3} ([^@]+@[^@]+)$'", input))
	}

	return warnings, errors
}

func unflattenStringSlice(input []interface{}) *[]string {
	output := make([]string, 0)

	if input != nil {
		for _, v := range input {
			output = append(output, v.(string))
		}
	}

	return &output
}

func flattenStringSlice(input *[]string) []interface{} {
	output := make([]interface{}, 0)

	if input != nil {
		for _, v := range *input {
			output = append(output, v)
		}
	}

	return output
}
