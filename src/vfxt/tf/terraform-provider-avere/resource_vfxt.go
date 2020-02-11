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
			"controller_address": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"controller_admin_username": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
			},
			"resource_group": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"location": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"network_resource_group": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"network_name": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"subnet_name": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"vfxt_cluster_name": &schema.Schema{
				Type:     schema.TypeString,
				Required: true,
				ForceNew: true,
			},
			"vfxt_admin_password": &schema.Schema{
				Type:      schema.TypeString,
				Required:  true,
				ForceNew:  true,
				Sensitive: true,
			},
			"vfxt_node_count": &schema.Schema{
				Type:     schema.TypeInt,
				Required: true,
				ValidateFunc: validation.IntBetween(3, 16),
			},
			"global_custom_settings": &schema.Schema{
				Type:     schema.TypeSet,
				Optional: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotWhiteSpace,
				},
				Set: schema.HashString,
			},
			"vfxt_os_version": &schema.Schema{
				Type:     schema.TypeString,
				Computed: true,
			},
			"vfxt_management_ip": &schema.Schema{
				Type:     schema.TypeString,
				Computed: true,
			},
			"vserver_ip_addresses": &schema.Schema{
				Type:     schema.TypeSet,
				Computed: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
				},
				Set: schema.HashString,
			},
			"node_names": &schema.Schema{
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

func fillAvereVfxt(d *schema.ResourceData) (*AvereVfxt, error) {
	controllerAddress := d.Get("controller_address").(string)
	controllerAdminUsername := d.Get("controller_admin_username").(string)
	authMethod, err := GetKeyFileAuthMethod()
	if err != nil {
		return nil, fmt.Errorf("failed to get key file: %s", err)
	}
	
	// get the optional fields
	globalCustomSettingsRaw := d.Get("global_custom_settings").(*schema.Set).List()
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
		utils.ExpandStringSlice(globalCustomSettingsRaw),
		avereOSVersion,
		managementIP,
		utils.ExpandStringSlice(vServerIPAddressesRaw),
		utils.ExpandStringSlice(nodeNamesRaw),
	), nil
}

func resourceVfxtCreate(d *schema.ResourceData, m interface{}) error {
	averevxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}

	if err := averevxt.CreateVfxt(); err != nil {
		return fmt.Errorf("failed to create cluster: %s\n", err)
	}

	for _, customSetting := range d.Get("global_custom_settings").([]string) {
		if err := averevxt.ApplyCustomSetting(customSetting) ; err != nil {
			return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", customSetting, err)
		}
	}

	d.Set("vfxt_os_version", averevxt.AvereOSVersion)
	d.Set("vfxt_management_ip", averevxt.ManagementIP)
	d.Set("vserver_ip_addresses", schema.NewSet(schema.HashString, utils.FlattenStringSlice(averevxt.VServerIPAddresses)))
	d.Set("node_names", schema.NewSet(schema.HashString, utils.FlattenStringSlice(averevxt.NodeNames)))

	// the management ip will uniquely identify the cluster in the VNET
	d.SetId(averevxt.ManagementIP)

	return resourceVfxtRead(d, m)
}

func resourceVfxtRead(d *schema.ResourceData, m interface{}) error {
	return nil
}

func resourceVfxtUpdate(d *schema.ResourceData, m interface{}) error {
	averevxt, err := fillAvereVfxt(d)
	if err != nil {
		return err
	}
	if d.HasChange("global_custom_settings") {
		old, new := d.GetChange("global_custom_settings")
		os := old.(*schema.Set)
		ns := new.(*schema.Set)

		removalList := os.Difference(ns)
		for _, v := range removalList.List() {
			if err := averevxt.RemoveCustomSetting(v.(string)) ; err != nil {
				return fmt.Errorf("ERROR: failed to remove custom setting '%s': %s", v.(string), err)
			}
		}

		// always apply the settings, as the operation is idempotent
		for _, v := range ns.List() {
			if err := averevxt.ApplyCustomSetting(v.(string)) ; err != nil {
				return fmt.Errorf("ERROR: failed to apply custom setting '%s': %s", v.(string), err)
			}
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
