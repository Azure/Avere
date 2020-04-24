// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bytes"
	"fmt"
	"github.com/hashicorp/terraform-plugin-sdk/helper/hashcode"
	"github.com/hashicorp/terraform-plugin-sdk/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/helper/validation"
	"github.com/terraform-providers/terraform-provider-azurerm/azurerm/utils"
	"log"

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
			run_local: {
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
				Type:     schema.TypeList,
				Optional: true,
				MaxItems: 3,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotEmpty,
				},
			},
			proxy_uri: {
				Type:     schema.TypeString,
				Optional: true,
				ForceNew: true,
			},
			cluster_proxy_uri: {
				Type:     schema.TypeString,
				Optional: true,
				ForceNew: true,
			},
			image_id: {
				Type:     schema.TypeString,
				Optional: true,
				ForceNew: true,
			},
			vfxt_cluster_name: {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			vfxt_admin_password: {
				Type:      schema.TypeString,
				Required:  true,
				ForceNew:  true,
				Sensitive: true,
			},
			vfxt_node_count: {
				Type:         schema.TypeInt,
				Required:     true,
				ValidateFunc: validation.IntBetween(3, 16),
			},
			global_custom_settings: {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotWhiteSpace,
				},
				Set: schema.HashString,
			},
			vserver_settings: {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotWhiteSpace,
				},
				Set: schema.HashString,
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
							}, false),
						},
						custom_settings: {
							Type:     schema.TypeSet,
							Optional: true,
							Elem: &schema.Schema{
								Type:         schema.TypeString,
								ValidateFunc: validation.StringIsNotWhiteSpace,
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
									core_filer_export: {
										Type:         schema.TypeString,
										Required:     true,
										ValidateFunc: validation.StringIsNotWhiteSpace,
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
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						container_name: {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						custom_settings: {
							Type:     schema.TypeSet,
							Optional: true,
							Elem: &schema.Schema{
								Type:         schema.TypeString,
								ValidateFunc: validation.StringIsNotWhiteSpace,
							},
							Set: schema.HashString,
						},
						junction_namespace_path: {
							Type:         schema.TypeString,
							Optional: true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
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
				Type:     schema.TypeSet,
				Computed: true,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
				Set: schema.HashString,
			},
			node_names: {
				Type:     schema.TypeSet,
				Computed: true,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
				Set: schema.HashString,
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
		// this only needs to be done on create since the controller's ssh
		// may take a while to become ready
		if err := VerifySSHConnection(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod); err != nil {
			return err
		}
	}

	if err := avereVfxt.Platform.CreateVfxt(avereVfxt); err != nil {
		return fmt.Errorf("failed to create cluster: %s\n", err)
	}

	d.Set(vfxt_management_ip, avereVfxt.ManagementIP)

	// the management ip will uniquely identify the cluster in the VNET
	d.SetId(avereVfxt.ManagementIP)

	if err := updateNtpServers(d, avereVfxt); err != nil {
		return err
	}

	if err := createGlobalSettings(d, avereVfxt); err != nil {
		return err
	}

	if err := createVServerSettings(d, avereVfxt); err != nil {
		return err
	}

	// add the new filers
	existingCoreFilers := make(map[string]*CoreFiler)
	if err := createOrUpdateCoreFilers(d, existingCoreFilers, avereVfxt); err != nil {
		return err
	}

	existingAzureStorageFilers := make(map[string]*AzureStorageFiler)
	if err := createOrUpdateAzureStorageFilers(d, existingAzureStorageFilers, avereVfxt); err != nil {
		return err
	}

	// add the new junctions
	if err := createJunctions(d, avereVfxt); err != nil {
		return err
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

	currentVServerIPAddresses, err := avereVfxt.GetVServerIPAddresses()
	if err != nil {
		return fmt.Errorf("error encountered while getting vserver addresses '%v'", err)
	}
	avereVfxt.VServerIPAddresses = &currentVServerIPAddresses
	d.Set(vserver_ip_addresses, schema.NewSet(schema.HashString, utils.FlattenStringSlice(avereVfxt.VServerIPAddresses)))

	nodeNames, err := avereVfxt.GetNodes()
	if err != nil {
		return fmt.Errorf("error encountered getting nodes '%v'", err)
	}
	avereVfxt.NodeNames = &nodeNames
	d.Set(node_names, schema.NewSet(schema.HashString, utils.FlattenStringSlice(avereVfxt.NodeNames)))
	if len(*(avereVfxt.NodeNames)) >= MinNodesCount {
		d.Set(vfxt_node_count, len(*(avereVfxt.NodeNames)))
	}

	return nil
}

func resourceVfxtUpdate(d *schema.ResourceData, m interface{}) error {
	log.Printf("[INFO] [resourceVfxtUpdate")
	defer log.Printf("[INFO] resourceVfxtUpdate]")

	avereVfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
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

	// update the core filers
	if d.HasChange(core_filer) || d.HasChange(azure_storage_filer) {
		// delete junctions before deleting core filers and Azure storage filers
		if err := deleteJunctions(d, avereVfxt); err != nil {
			return err
		}
		existingCoreFilers, existingAzureStorageFilers, err := avereVfxt.GetExistingFilers()
		if err != nil {
			return err
		}
		if err := deleteCoreFilers(d, existingCoreFilers, avereVfxt); err != nil {
			return err
		}
		if err := deleteAzureStorageFilers(d, existingAzureStorageFilers, avereVfxt); err != nil {
			return err
		}
		// refresh the known filers
		existingCoreFilers, existingAzureStorageFilers, err = avereVfxt.GetExistingFilers()
		// create core filers before adding junctions
		if err := createOrUpdateCoreFilers(d, existingCoreFilers, avereVfxt); err != nil {
			return err
		}
		if err := createOrUpdateAzureStorageFilers(d, existingAzureStorageFilers, avereVfxt); err != nil {
			return err
		}
		// the junctions are embedded in the core filers, add the new junctions
		if err := createJunctions(d, avereVfxt); err != nil {
			return err
		}
	}

	// scale the cluster if node changed
	if d.HasChange(vfxt_node_count) {
		if err := scaleCluster(d, avereVfxt); err != nil {
			return err
		}
	}

	return resourceVfxtRead(d, m)
}

func resourceVfxtDelete(d *schema.ResourceData, m interface{}) error {
	log.Printf("[INFO] [resourceVfxtDelete")
	defer log.Printf("[INFO] resourceVfxtDelete]")

	averevfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if err := averevfxt.Platform.DestroyVfxt(averevfxt); err != nil {
		return fmt.Errorf("failed to destroy cluster: %s\n", err)
	}

	d.Set(vfxt_management_ip, averevfxt.ManagementIP)
	d.Set(vserver_ip_addresses, averevfxt.VServerIPAddresses)
	d.Set(node_names, averevfxt.NodeNames)

	// acknowledge deletion of the vfxt
	d.SetId("")

	return nil
}

func fillAvereVfxt(d *schema.ResourceData) (*AvereVfxt, error) {
	var err error
	var controllerAddress, controllerAdminUsername, controllerAdminPassword string
	
	runLocal := d.Get(run_local).(bool)

	var authMethod ssh.AuthMethod
	if runLocal == false {
		if v, exists := d.GetOk(controller_address) ; exists {
			controllerAddress = v.(string)
		} else {
			return nil, fmt.Errorf("missing argument '%s'", controller_address)
		}
		if v, exists := d.GetOk(controller_admin_username) ; exists {
			controllerAdminUsername = v.(string)
		} else {
			return nil, fmt.Errorf("missing argument '%s'", controller_admin_username)
		}
		if v, exists := d.GetOk(controller_admin_password) ; exists {
			controllerAdminPassword = v.(string)
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
	vServerIPAddressesRaw := d.Get(vserver_ip_addresses).(*schema.Set).List()
	nodeNamesRaw := d.Get(node_names).(*schema.Set).List()

	return NewAvereVfxt(
		controllerAddress,
		controllerAdminUsername,
		authMethod,
		runLocal,
		iaasPlatform,
		d.Get(vfxt_cluster_name).(string),
		d.Get(vfxt_admin_password).(string),
		d.Get(vfxt_node_count).(int),
		utils.ExpandStringSlice(d.Get(ntp_servers).([]interface{})),
		d.Get(proxy_uri).(string),
		d.Get(cluster_proxy_uri).(string),
		d.Get(image_id).(string),
		managementIP,
		utils.ExpandStringSlice(vServerIPAddressesRaw),
		utils.ExpandStringSlice(nodeNamesRaw),
	), nil
}

func updateNtpServers(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	ntpServers := utils.ExpandStringSlice(d.Get(ntp_servers).([]interface{}))
	if len(*ntpServers) == 0 {
		return nil
	}
	return avereVfxt.SetNtpServers(ntpServers)
}

func createGlobalSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	for _, v := range d.Get(global_custom_settings).(*schema.Set).List() {
		if err := avereVfxt.CreateCustomSetting(v.(string)); err != nil {
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

func createOrUpdateCoreFilers(d *schema.ResourceData, existingCoreFilers map[string]*CoreFiler, averevfxt *AvereVfxt) error {
	// get the core filers from the model
	new := d.Get(core_filer)
	newFilers, err := expandCoreFilers(new.(*schema.Set).List())
	if err != nil {
		return err
	}

	// compare old and new core filers and raise error if any change to fqdn or cache policy
	if err := EnsureNoCoreAttributeChangeForExistingFilers(existingCoreFilers, newFilers); err != nil {
		return err
	}

	// add any new filers
	for k, v := range newFilers {
		if _, ok := existingCoreFilers[k]; !ok {
			if err := averevfxt.CreateCoreFiler(v); err != nil {
				return err
			}
		}
		if err != nil {
			return err
		}
		// update modified settings and add new settings on the existing filers
		if err := averevfxt.RemoveFilerCustomSettings(v.Name, v.CustomSettings); err != nil {
			return err
		}
		if err := averevfxt.AddFilerCustomSettings(v.Name, v.CustomSettings); err != nil {
			return err
		}
	}

	return nil
}

func createOrUpdateAzureStorageFilers(d *schema.ResourceData, existingAzureStorageFilers map[string]*AzureStorageFiler, averevfxt *AvereVfxt) error {
	// get the storage filers from the model
	new := d.Get(azure_storage_filer)
	newAzureStorageFilers, err := expandAzureStorageFilers(new.(*schema.Set).List())
	if err != nil {
		return err
	}

	// add any new filers
	for k, v := range newAzureStorageFilers {
		if _, ok := existingAzureStorageFilers[k]; !ok {
			if err := averevfxt.CreateAzureStorageFiler(v); err != nil {
				return err
			}
		}
		if err != nil {
			return err
		}
		// update modified settings and add new settings on the existing filers
		if err := averevfxt.RemoveFilerCustomSettings(v.GetCloudFilerName(), v.CustomSettings); err != nil {
			return err
		}
		if err := averevfxt.AddFilerCustomSettings(v.GetCloudFilerName(), v.CustomSettings); err != nil {
			return err
		}
	}

	return nil
}

func deleteCoreFilers(d *schema.ResourceData, existingCoreFilers map[string]*CoreFiler, averevfxt *AvereVfxt) error {
	new := d.Get(core_filer)
	newFilers, err := expandCoreFilers(new.(*schema.Set).List())
	if err != nil {
		return err
	}

	// delete any removed filers
	for k := range existingCoreFilers {
		if _, ok := newFilers[k]; ok {
			// the filer still exists
			continue
		}
		if err := averevfxt.DeleteFiler(k); err != nil {
			return err
		}
	}

	return nil
}

func deleteAzureStorageFilers(d *schema.ResourceData, existingAzureStorageFilers map[string]*AzureStorageFiler, averevfxt *AvereVfxt) error {
	new := d.Get(azure_storage_filer)
	newAzureStorageFilers, err := expandAzureStorageFilers(new.(*schema.Set).List())
	if err != nil {
		return err
	}

	// delete any removed azure storage filers
	for k, v := range existingAzureStorageFilers {
		if _, ok := newAzureStorageFilers[k]; ok {
			// the filer still exists
			continue
		}
		if err := averevfxt.DeleteFiler(k); err != nil {
			return err
		}
		if err := averevfxt.DeleteAzureStorageCredentials(v); err != nil {
			return err
		}
	}

	return nil
}

func createJunctions(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	newJunctions, err := expandAllJunctions(d)
	if err != nil {
		return err
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

func deleteJunctions(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	newJunctions, err := expandAllJunctions(d)
	if err != nil {
		return err
	}

	// get the map of existing junctions
	existingJunctions, err := averevfxt.GetExistingJunctions()
	if err != nil {
		return err
	}

	// delete any removed or updated junctions
	for k, existingJunction := range existingJunctions {
		if newJunction, ok := newJunctions[k]; ok && newJunction.IsEqual(existingJunction) {
			// the junction exists, and is the same as previous
			continue
		}

		if err := averevfxt.DeleteJunction(existingJunction.NameSpacePath); err != nil {
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

func expandCoreFilers(l []interface{}) (map[string]*CoreFiler, error) {
	results := make(map[string]*CoreFiler)
	for _, v := range l {
		input := v.(map[string]interface{})

		// get the properties
		name := input[core_filer_name].(string)
		fqdnOrPrimaryIp := input[fqdn_or_primary_ip].(string)
		cachePolicy := input[cache_policy].(string)
		customSettingsRaw := input[custom_settings].(*schema.Set).List()
		customSettings := make([]*CustomSetting, len(customSettingsRaw), len(customSettingsRaw))
		for i, v := range customSettingsRaw {
			customSettings[i] = initializeCustomSetting(v.(string))
		}
		// verify no duplicates
		if _, ok := results[name]; ok {
			return nil, fmt.Errorf("Error: two or more core filers share the same key '%s'", name)
		}

		// add to map
		output := &CoreFiler{
			Name:            name,
			FqdnOrPrimaryIp: fqdnOrPrimaryIp,
			CachePolicy:     cachePolicy,
			CustomSettings:  customSettings,
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
		customSettingsRaw := input[custom_settings].(*schema.Set).List()
		customSettings := make([]*CustomSetting, len(customSettingsRaw), len(customSettingsRaw))
		for i, v := range customSettingsRaw {
			customSettings[i] = initializeCustomSetting(v.(string))
		}

		// add to map
		output := &AzureStorageFiler{
			AccountName:    name,
			Container:      container,
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
			junction := &Junction{
				NameSpacePath:    junctionRaw[namespace_path].(string),
				CoreFilerName:    coreFilerName,
				CoreFilerExport:  junctionRaw[core_filer_export].(string),
				SharePermissions: PermissionsPreserve,
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
		namespacePath := input[junction_namespace_path].(string)

		junction := &Junction{
			NameSpacePath:    namespacePath,
			CoreFilerName:    cloudFilerName,
			CoreFilerExport:  CloudFilerExport,
			SharePermissions: PermissionsModebits,
		}
		// verify no duplicates
		if _, ok := results[junction.NameSpacePath]; ok {
			return fmt.Errorf("Error: two or more junctions share the same namespace_path '%s'", junction.NameSpacePath)
		}
		results[junction.NameSpacePath] = junction
	}
	return nil
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
		if v, ok := m[custom_settings]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(*schema.Set).List()))
		}
		if v, ok := m[junction_namespace_path]; ok {
			buf.WriteString(fmt.Sprintf("%s;", v.(string)))
		}
	}
	return hashcode.String(buf.String())
}
