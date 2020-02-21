// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"github.com/hashicorp/terraform-plugin-sdk/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/helper/validation"
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
			"controller_address": {
				Type:     schema.TypeString,
				Required: true,
			},
			"controller_admin_username": {
				Type:     schema.TypeString,
				Required: true,
			},
			"controller_admin_password": {
				Type: schema.TypeString,
				// the ssh key will be used if the password is not specified
				Optional:  true,
				Sensitive: true,
			},
			"resource_group": {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"location": {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"network_resource_group": {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"network_name": {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"proxy_uri": {
				Type:     schema.TypeString,
				Optional: true,
				ForceNew: true,
			},
			"cluster_proxy_uri": {
				Type:     schema.TypeString,
				Optional: true,
				ForceNew: true,
			},
			"subnet_name": {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"vfxt_cluster_name": {
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"vfxt_admin_password": {
				Type:      schema.TypeString,
				Required:  true,
				ForceNew:  true,
				Sensitive: true,
			},
			"vfxt_node_count": {
				Type:         schema.TypeInt,
				Required:     true,
				ValidateFunc: validation.IntBetween(3, 16),
			},
			"global_custom_settings": {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotWhiteSpace,
				},
				Set: schema.HashString,
			},
			"vserver_settings": {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotWhiteSpace,
				},
				Set: schema.HashString,
			},
			"core_filer": {
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Resource{
					Schema: map[string]*schema.Schema{
						"name": {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						"fqdn_or_primary_ip": {
							Type:         schema.TypeString,
							Required:     true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						"cache_policy": {
							Type:     schema.TypeString,
							Required: true,
							ValidateFunc: validation.StringInSlice([]string{
								CachePolicyClientsBypass,
								CachePolicyReadCaching,
								CachePolicyReadWriteCaching,
								CachePolicyFullCaching,
								CachePolicyTransitioningClients,
							}, false),
						},
						"custom_settings": {
							Type:     schema.TypeSet,
							Optional: true,
							Elem: &schema.Schema{
								Type:         schema.TypeString,
								ValidateFunc: validation.StringIsNotWhiteSpace,
							},
							Set: schema.HashString,
						},
						"junction": {
							Type:     schema.TypeSet,
							Optional: true,
							Elem: &schema.Resource{
								Schema: map[string]*schema.Schema{
									"namespace_path": {
										Type:         schema.TypeString,
										Required:     true,
										ValidateFunc: validation.StringIsNotWhiteSpace,
									},
									"core_filer_export": {
										Type:         schema.TypeString,
										Required:     true,
										ValidateFunc: validation.StringIsNotWhiteSpace,
									},
								},
							},
						},
					},
				},
			},
			"vfxt_os_version": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"vfxt_management_ip": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"vserver_ip_addresses": {
				Type:     schema.TypeSet,
				Computed: true,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
				Set: schema.HashString,
			},
			"node_names": {
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
	avereVfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	// this only needs to be done on create since the controller's ssh
	// may take a while to become ready
	if err := VerifySSHConnection(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod); err != nil {
		return err
	}

	if err := avereVfxt.CreateVfxt(); err != nil {
		return fmt.Errorf("failed to create cluster: %s\n", err)
	}

	d.Set("vfxt_os_version", avereVfxt.AvereOSVersion)
	d.Set("vfxt_management_ip", avereVfxt.ManagementIP)
	d.Set("vserver_ip_addresses", schema.NewSet(schema.HashString, utils.FlattenStringSlice(avereVfxt.VServerIPAddresses)))
	d.Set("node_names", schema.NewSet(schema.HashString, utils.FlattenStringSlice(avereVfxt.NodeNames)))

	// the management ip will uniquely identify the cluster in the VNET
	d.SetId(avereVfxt.ManagementIP)

	if err := createGlobalSettings(d, avereVfxt); err != nil {
		return err
	}

	if err := createVServerSettings(d, avereVfxt); err != nil {
		return err
	}

	// add the new core filers
	if err := createOrUpdateCoreFilers(d, avereVfxt); err != nil {
		return err
	}

	// add the new junctions
	if err := createJunctions(d, avereVfxt); err != nil {
		return err
	}

	return resourceVfxtRead(d, m)
}

func resourceVfxtRead(d *schema.ResourceData, m interface{}) error {
	return nil
}

func resourceVfxtUpdate(d *schema.ResourceData, m interface{}) error {
	avereVfxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if d.HasChange("global_custom_settings") {
		if err := deleteGlobalSettings(d, avereVfxt); err != nil {
			return err
		}
		if err := createGlobalSettings(d, avereVfxt); err != nil {
			return err
		}
	}

	if d.HasChange("vserver_settings") {
		if err := deleteVServerSettings(d, avereVfxt); err != nil {
			return err
		}
		if err := createVServerSettings(d, avereVfxt); err != nil {
			return err
		}
	}

	// update the core filers
	if d.HasChange("core_filer") {
		// delete junctions before delete core filers
		if err := deleteJunctions(d, avereVfxt); err != nil {
			return err
		}
		if err := deleteCoreFilers(d, avereVfxt); err != nil {
			return err
		}
		// create core filers before adding junctions
		if err := createOrUpdateCoreFilers(d, avereVfxt); err != nil {
			return err
		}
		// the junctions are embedded in the core filers, add the new junctions
		if err := createJunctions(d, avereVfxt); err != nil {
			return err
		}
	}

	// scale the cluster if node changed
	if d.HasChange("vfxt_node_count") {
		if err := scaleCluster(d, avereVfxt); err != nil {
			return err
		}
	}

	return resourceVfxtRead(d, m)
}

func resourceVfxtDelete(d *schema.ResourceData, m interface{}) error {
	averevxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if err := averevxt.DestroyVfxt(); err != nil {
		return fmt.Errorf("failed to destroy cluster: %s\n", err)
	}

	d.Set("vfxt_os_version", averevxt.AvereOSVersion)
	d.Set("vfxt_management_ip", averevxt.ManagementIP)
	d.Set("vserver_ip_addresses", averevxt.VServerIPAddresses)
	d.Set("node_names", averevxt.NodeNames)

	// acknowledge deletion of the vfxt
	d.SetId("")

	return nil
}

func fillAvereVfxt(d *schema.ResourceData) (*AvereVfxt, error) {
	controllerAddress := d.Get("controller_address").(string)
	controllerAdminUsername := d.Get("controller_admin_username").(string)
	controllerAdminPassword := d.Get("controller_admin_password").(string)
	var authMethod ssh.AuthMethod
	if len(controllerAdminPassword) > 0 {
		authMethod = GetPasswordAuthMethod(controllerAdminPassword)
	} else {
		var err error
		authMethod, err = GetKeyFileAuthMethod()
		if err != nil {
			return nil, fmt.Errorf("failed to get key file: %s", err)
		}
	}

	// get the optional fields
	var avereOSVersion string
	if val, ok := d.Get("vfxt_os_version").(string); ok {
		avereOSVersion = val
	}
	var managementIP string
	if val, ok := d.Get("vfxt_management_ip").(string); ok {
		managementIP = val
	}
	vServerIPAddressesRaw := d.Get("vserver_ip_addresses").(*schema.Set).List()
	nodeNamesRaw := d.Get("node_names").(*schema.Set).List()

	return NewAvereVfxt(
		controllerAddress,
		controllerAdminUsername,
		authMethod,
		d.Get("resource_group").(string),
		d.Get("location").(string),
		d.Get("vfxt_cluster_name").(string),
		d.Get("vfxt_admin_password").(string),
		d.Get("vfxt_node_count").(int),
		d.Get("network_resource_group").(string),
		d.Get("network_name").(string),
		d.Get("subnet_name").(string),
		d.Get("proxy_uri").(string),
		d.Get("cluster_proxy_uri").(string),
		avereOSVersion,
		managementIP,
		utils.ExpandStringSlice(vServerIPAddressesRaw),
		utils.ExpandStringSlice(nodeNamesRaw),
	), nil
}

func createGlobalSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	// apply the global custom settings
	for _, v := range d.Get("global_custom_settings").(*schema.Set).List() {
		if err := avereVfxt.CreateCustomSetting(v.(string)); err != nil {
			return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", v.(string), err)
		}
	}
	return nil
}

func deleteGlobalSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	// update the global customer settings
	if d.HasChange("global_custom_settings") {
		old, new := d.GetChange("global_custom_settings")
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
	for _, v := range d.Get("vserver_settings").(*schema.Set).List() {
		if err := avereVfxt.CreateVServerSetting(v.(string)); err != nil {
			return fmt.Errorf("ERROR: failed to apply VServer setting '%s': %s", v.(string), err)
		}
	}
	return nil
}

func deleteVServerSettings(d *schema.ResourceData, avereVfxt *AvereVfxt) error {
	if d.HasChange("vserver_settings") {
		old, new := d.GetChange("vserver_settings")
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

func createOrUpdateCoreFilers(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	new := d.Get("core_filer")
	newFilers, err := expandCoreFilers(new.(*schema.Set).List())
	if err != nil {
		return err
	}
	// get the list of existing core filers
	existingFilers, err := averevfxt.GetExistingFilers()
	if err != nil {
		return err
	}

	// compare old and new core filers and raise error if any change
	if err := EnsureNoCoreAttributeChangeForExistingFilers(existingFilers, newFilers); err != nil {
		return err
	}

	// add any new filers
	for k, v := range newFilers {
		if _, ok := existingFilers[k]; !ok {
			if err := averevfxt.CreateCoreFiler(v); err != nil {
				return err
			}
		}
		if err != nil {
			return err
		}
		// update modified settings and add new settings on the existing filers
		if err := averevfxt.RemoveCoreFilerCustomSettings(v); err != nil {
			return err
		}
		if err := averevfxt.AddCoreFilerCustomSettings(v); err != nil {
			return err
		}
	}

	return nil
}

func deleteCoreFilers(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	new := d.Get("core_filer")
	newFilers, err := expandCoreFilers(new.(*schema.Set).List())
	if err != nil {
		return err
	}
	// get the list of existing core filers
	existingFilers, err := averevfxt.GetExistingFilers()
	if err != nil {
		return err
	}

	// delete any removed filers
	for k, v := range existingFilers {
		if _, ok := newFilers[k]; ok {
			// the filer still exists
			continue
		}
		if err := averevfxt.DeleteCoreFiler(v.Name); err != nil {
			return err
		}
	}

	return nil
}

func createJunctions(d *schema.ResourceData, averevfxt *AvereVfxt) error {
	new := d.Get("core_filer")
	newJunctions, err := expandJunctions(new.(*schema.Set).List())
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
	new := d.Get("core_filer")
	newJunctions, err := expandJunctions(new.(*schema.Set).List())
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
		if newJunction, ok := newJunctions[k]; ok && *newJunction == *existingJunction {
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
	oldRaw, newRaw := d.GetChange("vfxt_node_count")
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
		name := input["name"].(string)
		fqdnOrPrimaryIp := input["fqdn_or_primary_ip"].(string)
		cachePolicy := input["cache_policy"].(string)
		customSettingsRaw := input["custom_settings"].(*schema.Set).List()
		customSettings := make([]string, len(customSettingsRaw), len(customSettingsRaw))
		for i, v := range customSettingsRaw {
			customSettings[i] = v.(string)
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

func expandJunctions(l []interface{}) (map[string]*Junction, error) {
	results := make(map[string]*Junction)
	for _, v := range l {
		input := v.(map[string]interface{})
		coreFilerName := input["name"].(string)
		junctions := input["junction"].(*schema.Set).List()
		for _, jv := range junctions {
			junctionRaw := jv.(map[string]interface{})
			junction := &Junction{
				NameSpacePath:   junctionRaw["namespace_path"].(string),
				CoreFilerName:   coreFilerName,
				CoreFilerExport: junctionRaw["core_filer_export"].(string),
			}
			// verify no duplicates
			if _, ok := results[junction.NameSpacePath]; ok {
				return nil, fmt.Errorf("Error: two or more junctions share the same namespace_path '%s'", junction.NameSpacePath)
			}
			results[junction.NameSpacePath] = junction
		}
	}
	return results, nil
}
