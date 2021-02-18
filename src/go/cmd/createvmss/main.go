// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
	"text/template"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-sdk-for-go/profiles/latest/compute/mgmt/compute"
	"github.com/Azure/azure-sdk-for-go/profiles/latest/network/mgmt/network"
	"github.com/Azure/go-autorest/autorest/azure/auth"
	"github.com/Azure/go-autorest/autorest/to"
)

type CacheWarmerCloudInit struct {
	LocalMountPath      string
	BootstrapAddress    string
	BootstrapExportPath string
	BootstrapScriptPath string
	EnvVars             string
	JobMountAddress     string
	JobExportPath       string
	JobBasePath         string
}

func InitializeCloutInit(
	bootstrapAddress string,
	bootstrapExportPath string,
	bootstrapScriptPath string,
	jobMountAddress string,
	jobExportPath string,
	jobBasePath string) *CacheWarmerCloudInit {

	localMountPath := "/b" // this is a temporary mount on the filesystem
	envVars := fmt.Sprintf(
		" BOOTSTRAP_PATH='%s' BOOTSTRAP_SCRIPT='%s' JOB_MOUNT_ADDRESS='%s' JOB_EXPORT_PATH='%s' JOB_BASE_PATH='%s' ",
		localMountPath,
		bootstrapScriptPath,
		jobMountAddress,
		jobExportPath,
		jobBasePath)

	return &CacheWarmerCloudInit{
		LocalMountPath:      localMountPath,
		BootstrapAddress:    bootstrapAddress,
		BootstrapExportPath: bootstrapExportPath,
		BootstrapScriptPath: bootstrapScriptPath,
		EnvVars:             envVars,
		JobMountAddress:     jobMountAddress,
		JobExportPath:       jobExportPath,
		JobBasePath:         jobBasePath,
	}
}

func (c *CacheWarmerCloudInit) GetCacheWarmerCloudInit() (string, error) {
	tmpl, err := template.New("cloudinit").Parse(c.getCacheWarmerRawCloudInitTemplateString())
	if err != nil {
		return "", err
	}
	var b bytes.Buffer
	if err := tmpl.Execute(&b, c); err != nil {
		return "", err
	}
	return b.String(), nil
}

func (c *CacheWarmerCloudInit) getCacheWarmerRawCloudInitTemplateString() string {
	return `#cloud-config
#
runcmd:
 - bash -c "set -x && ((apt-get update && apt-get install -y nfs-common) || (sleep 10 && apt-get update && apt-get install -y nfs-common) || (sleep 10 && apt-get update && apt-get install -y nfs-common)) && mkdir -p {{.LocalMountPath}} && r=5 && for i in $(seq 1 $r); do mount -o 'hard,nointr,proto=tcp,mountproto=tcp,retry=30' {{.BootstrapAddress}}:{{.BootstrapExportPath}} {{.LocalMountPath}} && break || [ $i == $r ] && break 0 || sleep 1; done && while [ ! -f {{.LocalMountPath}}{{.BootstrapScriptPath}} ]; do sleep 10; done && {{.EnvVars}} /bin/bash {{.LocalMountPath}}{{.BootstrapScriptPath}} 2>&1 | tee -a /var/log/bootstrap.log && umount {{.LocalMountPath}} && rmdir {{.LocalMountPath}}"`
}

type ComputeMetadata struct {
	SubscriptionId string `json:"subscriptionId"`
	ResourceGroup  string `json:"resourceGroupName"`
	Location       string `json:"location"`
	Name           string `json:"name"`
}

func GetComputeMetadata() (*ComputeMetadata, error) {
	client := &http.Client{}

	req, err := http.NewRequest("GET", "http://169.254.169.254/metadata/instance/compute", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Add("Metadata", "True")

	q := req.URL.Query()
	q.Add("format", "json")
	q.Add("api-version", "2019-11-01")
	req.URL.RawQuery = q.Encode()

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()
	resp_body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var computeMetadata ComputeMetadata
	if err := json.Unmarshal([]byte(resp_body), &computeMetadata); err != nil {
		return nil, err
	}
	return &computeMetadata, nil
}

func GetResourceName(id string) string {
	i := len(id) - 1
	for i >= 0 && id[i] != byte('/') {
		i--
	}
	return id[i+1:]
}

func SwapResourceName(id string, resourceName string) string {
	i := len(id) - 1
	for i >= 0 && id[i] != byte('/') {
		i--
	}
	basename := id[:i+1]
	return basename + resourceName
}

type AzureClients struct {
	VMClient      compute.VirtualMachinesClient
	VMSSClient    compute.VirtualMachineScaleSetsClient
	NICClient     network.InterfacesClient
	LocalMetadata ComputeMetadata
}

func InitializeAzureClients() (*AzureClients, error) {
	computeMetadata, err := GetComputeMetadata()
	if err != nil {
		return nil, fmt.Errorf("error retrieving instance metadata: %v\n", err)
	}

	authorizer, err := auth.NewAuthorizerFromEnvironment()
	if err != nil {
		return nil, fmt.Errorf("ERROR: authorizer from environment failed: %s", err)
	}

	vmClient := compute.NewVirtualMachinesClient(computeMetadata.SubscriptionId)
	vmClient.Authorizer = authorizer
	vmssClient := compute.NewVirtualMachineScaleSetsClient(computeMetadata.SubscriptionId)
	vmssClient.Authorizer = authorizer
	nicClient := network.NewInterfacesClient(computeMetadata.SubscriptionId)
	nicClient.Authorizer = authorizer

	return &AzureClients{
		VMClient:      vmClient,
		VMSSClient:    vmssClient,
		NICClient:     nicClient,
		LocalMetadata: *computeMetadata,
	}, nil
}

// GetSubnetId returns the subnet of the current VM
func GetSubnetId(ctx context.Context, azureClients *AzureClients) (string, error) {
	vm, err := azureClients.VMClient.Get(ctx, azureClients.LocalMetadata.ResourceGroup, azureClients.LocalMetadata.Name, compute.InstanceView)
	if err != nil {
		return "", fmt.Errorf("error getting the vmdata: %v", err)
	}

	if vm.VirtualMachineProperties == nil ||
		vm.VirtualMachineProperties.NetworkProfile == nil ||
		vm.VirtualMachineProperties.NetworkProfile.NetworkInterfaces == nil ||
		len((*vm.VirtualMachineProperties.NetworkProfile.NetworkInterfaces)) == 0 ||
		(*vm.VirtualMachineProperties.NetworkProfile.NetworkInterfaces)[0].ID == nil {
		return "", fmt.Errorf("unable to retreive nic for the local compute vm")
	}

	nicId := *(*vm.VirtualMachineProperties.NetworkProfile.NetworkInterfaces)[0].ID
	nicName := GetResourceName(nicId)
	nic, err := azureClients.NICClient.Get(ctx, azureClients.LocalMetadata.ResourceGroup, nicName, "")
	if err != nil {
		return "", fmt.Errorf("error getting the nic data for group '%s', nic '%s': %v", azureClients.LocalMetadata.ResourceGroup, nicName, err)
	}
	if nic.InterfacePropertiesFormat == nil ||
		nic.InterfacePropertiesFormat.IPConfigurations == nil ||
		len((*nic.InterfacePropertiesFormat.IPConfigurations)) == 0 {
		return "", fmt.Errorf("nic '%s' has no ip configurations", nicId)
	}

	ipConfig := (*nic.InterfacePropertiesFormat.IPConfigurations)[0]
	if ipConfig.InterfaceIPConfigurationPropertiesFormat == nil ||
		ipConfig.InterfaceIPConfigurationPropertiesFormat.Subnet == nil ||
		ipConfig.InterfaceIPConfigurationPropertiesFormat.Subnet.ID == nil {
		return "", fmt.Errorf("nic '%s' ip configuration has no subnet", nicId)
	}

	return *(*nic.InterfacePropertiesFormat.IPConfigurations)[0].Subnet.ID, nil
}

func createCacheWarmerVmssModel(
	vmssName string,
	location string,
	vmssSKU string,
	nodeCount int64,
	userName string,
	password string,
	sshKeyData string,
	publisher string,
	offer string,
	sku string,
	priority compute.VirtualMachinePriorityTypes,
	evictionPolicy compute.VirtualMachineEvictionPolicyTypes,
	subnetId string,
	customData string) compute.VirtualMachineScaleSet {
	passwordPtr := to.StringPtr(password)
	if len(sshKeyData) > 0 {
		// disable password if using ssh key
		passwordPtr = nil
	}

	var linuxConfiguration *compute.LinuxConfiguration
	if len(sshKeyData) > 0 {
		linuxConfiguration = &compute.LinuxConfiguration{
			DisablePasswordAuthentication: to.BoolPtr(true),
			SSH: &compute.SSHConfiguration{
				PublicKeys: &[]compute.SSHPublicKey{
					{
						Path:    to.StringPtr(fmt.Sprintf("/home/%s/.ssh/authorized_keys", userName)),
						KeyData: to.StringPtr(sshKeyData),
					},
				},
			},
		}
	}

	// create the vmss model
	return compute.VirtualMachineScaleSet{
		Name:     to.StringPtr(vmssName),
		Location: to.StringPtr(location),
		Sku: &compute.Sku{
			Name:     to.StringPtr(vmssSKU),
			Capacity: to.Int64Ptr(nodeCount),
		},
		VirtualMachineScaleSetProperties: &compute.VirtualMachineScaleSetProperties{
			Overprovision: to.BoolPtr(false),
			UpgradePolicy: &compute.UpgradePolicy{
				Mode: compute.Manual,
			},
			SinglePlacementGroup: to.BoolPtr(false),
			VirtualMachineProfile: &compute.VirtualMachineScaleSetVMProfile{
				Priority:       priority,
				EvictionPolicy: evictionPolicy,
				OsProfile: &compute.VirtualMachineScaleSetOSProfile{
					ComputerNamePrefix: to.StringPtr(vmssName),
					AdminUsername:      to.StringPtr(userName),
					AdminPassword:      passwordPtr,
					CustomData:         to.StringPtr(base64.StdEncoding.EncodeToString([]byte(customData))),
					LinuxConfiguration: linuxConfiguration,
				},
				StorageProfile: &compute.VirtualMachineScaleSetStorageProfile{
					ImageReference: &compute.ImageReference{
						Offer:     to.StringPtr(offer),
						Publisher: to.StringPtr(publisher),
						Sku:       to.StringPtr(sku),
						Version:   to.StringPtr("latest"),
					},
				},
				NetworkProfile: &compute.VirtualMachineScaleSetNetworkProfile{
					NetworkInterfaceConfigurations: &[]compute.VirtualMachineScaleSetNetworkConfiguration{
						{
							Name: to.StringPtr(vmssName),
							VirtualMachineScaleSetNetworkConfigurationProperties: &compute.VirtualMachineScaleSetNetworkConfigurationProperties{
								Primary: to.BoolPtr(true),
								//EnableAcceleratedNetworking: to.BoolPtr(true),
								//EnableIPForwarding:          to.BoolPtr(false),
								IPConfigurations: &[]compute.VirtualMachineScaleSetIPConfiguration{
									{
										Name: to.StringPtr("internal"),
										VirtualMachineScaleSetIPConfigurationProperties: &compute.VirtualMachineScaleSetIPConfigurationProperties{
											Subnet: &compute.APIEntityReference{
												ID: to.StringPtr(subnetId),
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}
}

func VmssExists(ctx context.Context, azureClients *AzureClients, name string) (bool, error) {
	_, err := azureClients.VMSSClient.Get(ctx, azureClients.LocalMetadata.ResourceGroup, name)
	if err != nil {
		if strings.Contains(err.Error(), "Code=\"ResourceNotFound\"") {
			return false, nil
		} else {
			return false, err
		}
	}
	return true, nil
}

func CreateVmss(ctx context.Context, azureClients *AzureClients, vmssModel compute.VirtualMachineScaleSet) (vmss compute.VirtualMachineScaleSet, err error) {
	log.Info.Printf("[CreateVmss %s %s", azureClients.LocalMetadata.ResourceGroup, *vmssModel.Name)
	start := time.Now()
	defer log.Info.Printf(" %s %s CreateVmss]", azureClients.LocalMetadata.ResourceGroup, *vmssModel.Name)

	future, err := azureClients.VMSSClient.CreateOrUpdate(ctx, azureClients.LocalMetadata.ResourceGroup, *vmssModel.Name, vmssModel)
	if err != nil {
		return vmss, fmt.Errorf("error creating '%s': %v, %v", *vmssModel.Name, err, future)
	}
	err = future.WaitForCompletionRef(ctx, azureClients.VMSSClient.Client)
	if err != nil {
		return vmss, fmt.Errorf("cannot get the vmss create or update future response: %v", err)
	}
	log.Info.Printf("CreateVmss(%s, %s) took %.2f seconds", azureClients.LocalMetadata.ResourceGroup, *vmssModel.Name, time.Now().Sub(start).Seconds())
	return future.Result(azureClients.VMSSClient)
}

func DeleteVmss(ctx context.Context, azureClients *AzureClients, name string) error {
	log.Info.Printf("[DeleteVmss %s %s", azureClients.LocalMetadata.ResourceGroup, name)
	start := time.Now()
	defer log.Info.Printf(" %s %s DeleteVmss]", azureClients.LocalMetadata.ResourceGroup, name)

	// passing nil instance ids will deallocate all VMs in the VMSS
	forceDelete := false
	future, err := azureClients.VMSSClient.Delete(ctx, azureClients.LocalMetadata.ResourceGroup, name, &forceDelete)
	if err != nil {
		return fmt.Errorf("cannot delete vmss (%s %s): %v", azureClients.LocalMetadata.ResourceGroup, name, err)
	}

	err = future.WaitForCompletionRef(ctx, azureClients.VMSSClient.Client)
	if err != nil {
		return fmt.Errorf("cannot get the vmss delete future response(%s %s): %v", azureClients.LocalMetadata.ResourceGroup, name, err)
	}

	log.Info.Printf("DeleteVmss(%s, %s) took %.2f seconds", azureClients.LocalMetadata.ResourceGroup, name, time.Now().Sub(start).Seconds())
	return nil
}

func ToggleVmss(ctx context.Context, azureClients *AzureClients) error {
	vmssName := "cwvmss"
	vmssExists, err := VmssExists(ctx, azureClients, vmssName)
	if err != nil {
		return err
	}
	if !vmssExists {

		localVMSubnetId, err := GetSubnetId(ctx, azureClients)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: failed to initialize Azure Clients: %s", err)
			os.Exit(1)
		}
		renderClientsSubnet := SwapResourceName(localVMSubnetId, "render_clients1")

		cacheWarmerCloudInit := InitializeCloutInit(
			"10.0.1.11", // bootstrapAddress string,
			"/nfs1data", // exportPath string,
			"/bootstrap/bootstrap.cachewarmer-worker.sh", // bootstrapScriptPath string,
			"10.0.1.11", // jobMountAddress string,
			"/nfs1data", // jobExportPath string,
			"/",         //jobBasePath string
		)

		customData, err := cacheWarmerCloudInit.GetCacheWarmerCloudInit()
		if err != nil {
			fmt.Fprintf(os.Stderr, "BUG BUG: customData retrieval hits the following error: %v", err)
			os.Exit(1)
		}
		log.Info.Printf("customData: '%s'", customData)

		cacheWarmerVmss := createCacheWarmerVmssModel(
			vmssName,                            // vmssName string,
			azureClients.LocalMetadata.Location, // location string,
			"Standard_D2s_v3",                   // vmssSKU string,
			1,                                   // nodeCount int64,
			"azureuser",                         // userName string,
			"TestPassword$",                     // password string,
			"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8fhkh3jpHUQsrUIezFB5k4Rq9giJM8G1Cr0u2IRMiqG++nat5hbOr3gODpTA0h11q9bzb6nJtK7NtDzIHx+w3YNIVpcTGLiUEsfUbY53IHg7Nl/p3/gkST3g0R6BSL7Hg45SfyvpH7kwY30MoVHG/6P3go4SKlYoHXlgaaNr3fMwUTIeE9ofvyS3fcr6xxlsoB6luKuEs50h0NGsE4QEnbfSY4Yd/C1ucc3mEw+QFXBIsENHfHfZYrLNHm2L8MXYVmAH8k//5sFs4Migln9GiUgEQUT6uOjowsZyXBbXwfT11og+syPkAq4eqjiC76r0w6faVihdBYVoc/UcyupgH azureuser@linuxvm", // sshKeyData string,
			"Canonical",         // publisher string,
			"UbuntuServer",      // offer string,
			"18.04-LTS",         // sku string,
			compute.Spot,        // priority compute.VirtualMachinePriorityTypes,
			compute.Delete,      // evictionPolicy compute.VirtualMachineEvictionPolicyTypes
			renderClientsSubnet, // subnetId string
			customData,
		)

		if _, err := CreateVmss(ctx, azureClients, cacheWarmerVmss); err != nil {
			return err
		}
	} else {
		if err := DeleteVmss(ctx, azureClients, vmssName); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	// setup the shared context
	ctx := context.Background()
	azureClients, err := InitializeAzureClients()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: failed to initialize Azure Clients: %s", err)
		os.Exit(1)
	}

	if err := ToggleVmss(ctx, azureClients); err != nil {
		fmt.Fprintf(os.Stderr, "error toggling vmss: %v", err)
		os.Exit(1)
	}
	log.Info.Printf("finished")
}
