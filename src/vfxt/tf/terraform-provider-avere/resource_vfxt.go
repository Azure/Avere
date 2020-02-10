package main

import (
	"fmt"
	"github.com/hashicorp/terraform-plugin-sdk/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/helper/validation"
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
			"vfxt_os_version": &schema.Schema{
				Type:     schema.TypeString,
				Computed: true,
			},
			"vfxt_management_ip": &schema.Schema{
				Type:     schema.TypeString,
				Computed: true,
			},
			"vserver_ip_addresses": &schema.Schema{
				Type:     schema.TypeList,
				Computed: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotWhiteSpace,
				},
			},
			"node_names": &schema.Schema{
				Type:     schema.TypeList,
				Computed: true,
				Elem: &schema.Schema{
					Type:         schema.TypeString,
					ValidateFunc: validation.StringIsNotWhiteSpace,
				},
			},
		},
	}
}

func resourceVfxtCreate(d *schema.ResourceData, m interface{}) error {
	controllerAddress := d.Get("controller_address").(string)
	controllerAdminUsername := d.Get("controller_admin_username").(string)
	authMethod, err := GetKeyFileAuthMethod()
	if err != nil {
		return fmt.Errorf("failed to get key file: %s", err)
	}

	averevxt := NewAvereVfxt(
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
	)

	if err := averevxt.CreateVfxt(); err != nil {
		return fmt.Errorf("failed to create cluster: %s\n", err)
	}

	d.Set("vfxt_os_version", averevxt.AvereOSVersion)
	d.Set("vfxt_management_ip", averevxt.ManagementIP)
	d.Set("vserver_ip_addresses", averevxt.VServerIPAddresses)
	d.Set("node_names", averevxt.NodeNames)

	// the management ip will uniquely identify the cluster in the VNET
	d.SetId(averevxt.ManagementIP)

	return resourceVfxtRead(d, m)
}

func resourceVfxtRead(d *schema.ResourceData, m interface{}) error {
	return nil
}

func resourceVfxtUpdate(d *schema.ResourceData, m interface{}) error {
	return resourceVfxtRead(d, m)
}

func resourceVfxtDelete(d *schema.ResourceData, m interface{}) error {
	controllerAddress := d.Get("controller_address").(string)
	controllerAdminUsername := d.Get("controller_admin_username").(string)
	authMethod, err := GetKeyFileAuthMethod()
	if err != nil {
		return fmt.Errorf("failed to get key file: %s", err)
	}

	averevxt := NewAvereVfxt(
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
	)
	averevxt.ManagementIP = d.Get("vfxt_management_ip").(string)

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
