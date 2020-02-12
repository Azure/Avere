// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"github.com/hashicorp/terraform-plugin-sdk/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/helper/validation"
	"github.com/terraform-providers/terraform-provider-azurerm/azurerm/utils"
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
				Type:     schema.TypeInt,
				Required: true,
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
							Type: schema.TypeString,
							Required: true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						"fqdn_or_primary_ip": {
							Type: schema.TypeString,
							Required: true,
							ValidateFunc: validation.StringIsNotWhiteSpace,
						},
						"cache_policy": {
							Type: schema.TypeString,
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
										Type: schema.TypeString,
										Required: true,
										ValidateFunc: validation.StringIsNotWhiteSpace,
									},
									"core_filer_export": {
										Type: schema.TypeString,
										Required: true,
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
					Type:         schema.TypeString,
				},
				Set: schema.HashString,
			},
			"node_names": {
				Type:     schema.TypeSet,
				Computed: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
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

	if err := avereVfxt.CreateVfxt(); err != nil {
		return fmt.Errorf("failed to create cluster: %s\n", err)
	}

	d.Set("vfxt_os_version", avereVfxt.AvereOSVersion)
	d.Set("vfxt_management_ip", avereVfxt.ManagementIP)
	d.Set("vserver_ip_addresses", schema.NewSet(schema.HashString, utils.FlattenStringSlice(avereVfxt.VServerIPAddresses)))
	d.Set("node_names", schema.NewSet(schema.HashString, utils.FlattenStringSlice(avereVfxt.NodeNames)))

	// the management ip will uniquely identify the cluster in the VNET
	d.SetId(avereVfxt.ManagementIP)

	// add the new core filers
	if err := updateCoreFilers(d, avereVfxt); err != nil {
		return err
	}

	// apply the global custom settings, if they fail, we can try to re-apply on the update
	for _, v := range d.Get("global_custom_settings").(*schema.Set).List() {
		if err := avereVfxt.ApplyCustomSetting(v.(string)) ; err != nil {
			return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", v.(string), err)
		}
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

	// update the global customer settings
	if d.HasChange("global_custom_settings") {
		old, new := d.GetChange("global_custom_settings")
		os := old.(*schema.Set)
		ns := new.(*schema.Set)

		removalList := os.Difference(ns)
		for _, v := range removalList.List() {
			if err := avereVfxt.RemoveCustomSetting(v.(string)) ; err != nil {
				return fmt.Errorf("ERROR: failed to remove custom setting '%s': %s", v.(string), err)
			}
		}

		// always apply the settings, as the operation is idempotent
		for _, v := range ns.List() {
			if err := avereVfxt.ApplyCustomSetting(v.(string)) ; err != nil {
				return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", v.(string), err)
			}
		}
	}

	// update the core filers
	if d.HasChange("core_filer") {
		if err := updateCoreFilers(d, avereVfxt); err != nil {
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
	authMethod, err := GetKeyFileAuthMethod()
	if err != nil {
		return nil, fmt.Errorf("failed to get key file: %s", err)
	}
	
	// get the optional fields
	var avereOSVersion string
	if val, ok := d.Get("vfxt_os_version").(string) ; ok {
		avereOSVersion = val
	}
	var managementIP string
	if val, ok := d.Get("vfxt_management_ip").(string) ; ok {
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
		avereOSVersion,
		managementIP,
		utils.ExpandStringSlice(vServerIPAddressesRaw),
		utils.ExpandStringSlice(nodeNamesRaw),
	), nil
}

func updateCoreFilers(d *schema.ResourceData, averevfxt *AvereVfxt) error {
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
	if err := EnsureNoCoreAttributeChangeForExistingFilers(existingFilers, newFilers) ; err != nil {
		return err
	}

	// delete any removed filers
	for k, v := range existingFilers {
		if _, ok := newFilers[k] ; ok {
			// the filer still exists
			continue
		}
		if err := averevfxt.DeleteCoreFiler(v.Name) ; err != nil {
			return err
		}
	}

	// add any new filers
	for k, v := range newFilers {
		if _, ok := existingFilers[k] ; ok {
			// the filer exists
			continue
		}
		if err := averevfxt.CreateCoreFiler(v) ; err != nil {
			return err
		}
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
		
		// verify no duplicates
		if _, ok := results[name] ; ok {
			return nil, fmt.Errorf("Error: two or more core filers share the same key '%s'", name)
		}

		// add to map
		output := &CoreFiler{
			Name: name,
			FqdnOrPrimaryIp: fqdnOrPrimaryIp,
			CachePolicy: cachePolicy,
		}
		results[name] = output
	}
	return results, nil
}
