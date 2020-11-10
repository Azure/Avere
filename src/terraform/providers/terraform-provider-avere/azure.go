// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hashicorp/terraform-plugin-sdk/helper/schema"
)

// Azure specific constants
const (
	AzCliLogFile        = "~/azcli.log"
	AzLoginRetryCount   = 18 // wait 3 minutes
	AzLoginSleepSeconds = 10
	AvereInstanceE32s   = "Standard_E32s_v3"
	AvereInstanceD16s   = "Standard_D16s_v3"
	AverOperatorRole    = "Avere Operator"
)

var validVFXTCharExtractRegexp = regexp.MustCompile(`[^_-a-z0-9]+`)

type Azure struct {
	ResourceGroup        string
	Location             string
	NetworkResourceGroup string
	NetworkName          string
	SubnetName           string
}

// matching strings for the vfxt.py output
var matchManagementIPAddressRegex = regexp.MustCompile(` management address: (\d+.\d+.\d+.\d+)`)
var matchManagementIPAddressRegex2 = regexp.MustCompile(`^address=(.*)$`)
var matchCreateFailure = regexp.MustCompile(`^(.*vfxt:ERROR.*)$`)
var matchVfxtFailure = regexp.MustCompile(`^(.*vFXTCreateFailure:.*)$`)
var matchVfxtNotFound = regexp.MustCompile(`(vfxt:ERROR - Cluster not found)`)

func NewAzureIaasPlatform(d *schema.ResourceData) (IaasPlatform, error) {
	// confirm rg and vnet subnet values were set as these are specified
	// as optional
	if _, ok := d.GetOk(azure_resource_group); !ok {
		return nil, fmt.Errorf("Error: '%s is not set", azure_resource_group)
	}
	if _, ok := d.GetOk(azure_network_resource_group); !ok {
		return nil, fmt.Errorf("Error: '%s is not set", azure_network_resource_group)
	}
	if _, ok := d.GetOk(azure_network_name); !ok {
		return nil, fmt.Errorf("Error: '%s is not set", azure_network_name)
	}
	if _, ok := d.GetOk(azure_subnet_name); !ok {
		return nil, fmt.Errorf("Error: '%s is not set", azure_subnet_name)
	}
	return Azure{
		ResourceGroup:        d.Get(azure_resource_group).(string),
		Location:             d.Get(location).(string),
		NetworkResourceGroup: d.Get(azure_network_resource_group).(string),
		NetworkName:          d.Get(azure_network_name).(string),
		SubnetName:           d.Get(azure_subnet_name).(string),
	}, nil
}

func (a Azure) CreateVfxt(avereVfxt *AvereVfxt) error {
	if err := VerifyAzLogin(avereVfxt); err != nil {
		return fmt.Errorf("Error verifying az cli login: %v", err)
	}
	if len(avereVfxt.AvereSshKeyData) > 0 {
		cmd := a.getEnsureAvereSshKeyData(avereVfxt.AvereSshKeyData)
		stdoutBuf, stderrBuf, err := avereVfxt.RunCommand(cmd)
		if err != nil {
			allErrors := getAllVfxtErrors(stdoutBuf, stderrBuf)
			return fmt.Errorf("Error ensuring public key: %v, '%s'", err, allErrors)
		}
	}

	cmd := a.getCreateVfxtCommand(avereVfxt)
	stdoutBuf, stderrBuf, err := avereVfxt.RunCommand(cmd)
	if err != nil {
		allErrors := getAllVfxtErrors(stdoutBuf, stderrBuf)
		return fmt.Errorf("Error creating vfxt: %v, from vfxt.py: '%s'", err, allErrors)
	}

	mgmtIP, err := getLastManagementIPAddress(stderrBuf)
	if err != nil {
		return fmt.Errorf("Error creating vfxt: %s", err)
	}
	avereVfxt.ManagementIP = mgmtIP

	if err = avereVfxt.EnsureClusterStable(); err != nil {
		return err
	}

	return nil
}

func (a Azure) AddIaasNodeToCluster(avereVfxt *AvereVfxt) error {
	cmd := a.getAddNodeToVfxtCommand(avereVfxt)
	if _, stderrBuf, err := avereVfxt.RunCommand(cmd); err != nil {
		return fmt.Errorf("Error adding node to vfxt: %v, from vfxt.py: '%s'", err, stderrBuf.String())
	}

	return nil
}

func (a Azure) DestroyVfxt(avereVfxt *AvereVfxt) error {
	if len(avereVfxt.ManagementIP) == 0 {
		return nil
	}
	cmd := a.getDestroyVfxtCommand(avereVfxt)
	stdoutBuf, stderrBuf, err := avereVfxt.RunCommand(cmd)
	if err != nil && !isVfxtNotFoundReported(stdoutBuf, stderrBuf) {
		allErrors := getAllVfxtErrors(stdoutBuf, stderrBuf)
		return fmt.Errorf("Error destroying vfxt: %v, from vfxt.py: '%s'", err, allErrors)
	}
	avereVfxt.ManagementIP = ""
	avereVfxt.VServerIPAddresses = &([]string{})
	avereVfxt.NodeNames = &([]string{})

	return nil
}

func (a Azure) DeleteVfxtIaasNode(avereVfxt *AvereVfxt, nodeName string) error {
	if err := VerifyAzLogin(avereVfxt); err != nil {
		return fmt.Errorf("Error verifying login: %v", err)
	}
	// delete the node
	deleteNodeCommand := a.getAzCliDeleteNodeCommand(avereVfxt, nodeName)
	_, stderrBuf, err := avereVfxt.RunCommand(deleteNodeCommand)
	if err != nil {
		return fmt.Errorf("Error deleting node: %v, %s", err, stderrBuf.String())
	}
	// delete the nic
	deleteNicCommand := a.getAzCliDeleteNicCommand(avereVfxt, nodeName)
	_, stderrBuf, err = avereVfxt.RunCommand(deleteNicCommand)
	if err != nil {
		return fmt.Errorf("Error deleting nic: %v, %s", err, stderrBuf.String())
	}
	// delete the disks
	deleteDisksCommand := a.getAzCliDeleteDisksCommand(avereVfxt, nodeName)
	_, stderrBuf, err = avereVfxt.RunCommand(deleteDisksCommand)
	if err != nil {
		return fmt.Errorf("Error deleting disks: %v, %s", err, stderrBuf.String())
	}
	return nil
}

// get the support name of format av0x2dCUSTOMER0x2dRESOURCE_GROUP-CLUSTER
// as defined in https://github.com/Azure/Avere/issues/959
func (a Azure) GetSupportName(avereVfxt *AvereVfxt, uniqueName string) (string, error) {
	supportNameParts := []string{SupportNamePrefix}

	// 1. customer name
	customerName := uniqueName
	if len(customerName) == 0 {
		subscriptionId, err := GetSubscriptionId(avereVfxt)
		if err != nil {
			return "", err
		}
		parts := strings.Split(subscriptionId, "-")
		if len(parts) > 0 && len(parts[0]) > 0 {
			customerName = ExtractValidVFXTNameChars(parts[0])
		}
		if len(customerName) == 0 {
			customerName = SupportNameUnknown
		}
	}
	supportNameParts = append(supportNameParts, customerName)

	// 2. resource group + cluster name
	resourceGroup := ExtractValidVFXTNameChars(a.ResourceGroup)
	if len(resourceGroup) == 0 {
		resourceGroup = SupportNameUnknown
	}
	supportNameParts = append(supportNameParts, fmt.Sprintf("%s%s", resourceGroup, avereVfxt.AvereVfxtName))

	return strings.Join(supportNameParts, SupportNameSeparator), nil
}

func ExtractValidVFXTNameChars(name string) string {
	noSpaceName := strings.ReplaceAll(name, " ", "_")
	return validVFXTCharExtractRegexp.ReplaceAllString(noSpaceName, "")
}

func CreateBucket(avereVfxt *AvereVfxt, storageAccountName string, bucket string) error {
	if err := VerifyAzLogin(avereVfxt); err != nil {
		return fmt.Errorf("Error verifying login: %v", err)
	}
	createContainerCommand := getAzCliCreateStorageContainerCommand(avereVfxt, storageAccountName, bucket)
	_, stderrBuf, err := avereVfxt.RunCommand(createContainerCommand)
	if err != nil {
		return fmt.Errorf("Error create container '%s' in storage account '%s' if container exists: %v, %s", bucket, storageAccountName, err, stderrBuf.String())
	}
	return nil
}

func BucketExists(avereVfxt *AvereVfxt, storageAccountName string, bucket string) (bool, error) {
	if err := VerifyAzLogin(avereVfxt); err != nil {
		return false, fmt.Errorf("Error verifying login: %v", err)
	}
	containerExistsCommand := getAzCliContainerExistsCommand(avereVfxt, storageAccountName, bucket)
	stdinBuf, stderrBuf, err := avereVfxt.RunCommand(containerExistsCommand)
	if err != nil {
		return false, fmt.Errorf("Error checking if container '%s' in storage account '%s': %v, %s", bucket, storageAccountName, err, stderrBuf.String())
	}
	type ContainerExists struct {
		Exists bool `json:"exists"`
	}
	var results ContainerExists
	if err := json.Unmarshal([]byte(stdinBuf.String()), &results); err != nil {
		return false, err
	}
	return results.Exists, nil
}

func BucketEmpty(avereVfxt *AvereVfxt, storageAccountName string, bucket string) (bool, error) {
	if err := VerifyAzLogin(avereVfxt); err != nil {
		return false, fmt.Errorf("Error verifying login: %v", err)
	}
	containerExistsCommand := getAzCliListFirstBlobCommand(avereVfxt, storageAccountName, bucket)
	stdinBuf, stderrBuf, err := avereVfxt.RunCommand(containerExistsCommand)
	if err != nil {
		return false, fmt.Errorf("Error listing first blob of container '%s' in storage account '%s': %v, %s", bucket, storageAccountName, err, stderrBuf.String())
	}
	var results []string
	if err := json.Unmarshal([]byte(stdinBuf.String()), &results); err != nil {
		return false, err
	}
	return len(results) == 0, nil
}

// GetKey gets the key for storing the cloud credential
func GetKey(avereVfxt *AvereVfxt, storageAccountName string) (string, error) {
	if err := VerifyAzLogin(avereVfxt); err != nil {
		return "", fmt.Errorf("Error verifying login: %v", err)
	}
	getStorageKeyCommand := getAzCliGetStorageKeyCommand(avereVfxt, storageAccountName)
	stdinBuf, stderrBuf, err := avereVfxt.RunCommand(getStorageKeyCommand)
	if err != nil {
		return "", fmt.Errorf("Error getting the storage account key for account '%s': %s %s", storageAccountName, err, stderrBuf.String())
	}
	var results string
	if err := json.Unmarshal([]byte(stdinBuf.String()), &results); err != nil {
		return "", err
	}
	return results, nil
}

// GetSubscriptionId gets the key for storing the cloud credential
func GetSubscriptionId(avereVfxt *AvereVfxt) (string, error) {
	if err := VerifyAzLogin(avereVfxt); err != nil {
		return "", fmt.Errorf("Error verifying login: %v", err)
	}
	getSubscriptionIdCommand := getAzCliGetSubscriptionIdCommand(avereVfxt)
	stdinBuf, stderrBuf, err := avereVfxt.RunCommand(getSubscriptionIdCommand)
	if err != nil {
		return "", fmt.Errorf("Error getting the subscription id: %s %s", err, stderrBuf.String())
	}
	var subscriptionId string
	if err := json.Unmarshal([]byte(stdinBuf.String()), &subscriptionId); err != nil {
		return "", err
	}

	if _, err := uuid.Parse(subscriptionId); err != nil {
		return "", fmt.Errorf("subscriptionId '%s' is an invalid UUID and fails with parse error: %v", subscriptionId, err)
	}

	return subscriptionId, nil
}

// VerifyAzLogin confirms that the auth was setup correctly.  The auth for
// Azure uses the managed identity of the controller to run Azure cli commands.
func VerifyAzLogin(avereVfxt *AvereVfxt) error {
	// it can take a while for the IMDS roles to propagate, retry until login succeeds
	verifyLoginCommand := getAzCliVerifyLoginCommand(avereVfxt)
	var err error
	err = nil
	for retries := 0; retries < AzLoginRetryCount; retries++ {
		if _, _, err = avereVfxt.RunCommand(verifyLoginCommand); err == nil {
			// success
			break
		} else {
			log.Printf("[ERROR] [%d/%d] SSH Failed with %v", retries, AzLoginRetryCount, err)
		}
		time.Sleep(AzLoginSleepSeconds * time.Second)
	}
	return err
}

func (a Azure) getEnsureAvereSshKeyData(publicKeyData string) string {
	return WrapCommandForLogging(fmt.Sprintf("echo '%s' > %s", publicKeyData, VfxtKeyPubFile), ShellLogFile)
}

func (a Azure) getCreateVfxtCommand(avereVfxt *AvereVfxt) string {
	vServerStr := ""
	if len(avereVfxt.FirstIPAddress) > 0 && len(avereVfxt.FirstIPAddress) > 0 {
		vServerStr = "--no-vserver"
	}

	return WrapCommandForLogging(fmt.Sprintf("%s --create --no-corefiler %s --nodes %d", a.getBaseVfxtCommand(avereVfxt), vServerStr, avereVfxt.NodeCount), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a Azure) getDestroyVfxtCommand(avereVfxt *AvereVfxt) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --destroy", a.getBaseVfxtCommand(avereVfxt)), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a Azure) getAddNodeToVfxtCommand(avereVfxt *AvereVfxt) string {
	// only adding one node at a time is stable
	return WrapCommandForLogging(fmt.Sprintf("%s --add-nodes --nodes 1", a.getBaseVfxtCommand(avereVfxt)), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a Azure) getBaseVfxtCommand(avereVfxt *AvereVfxt) string {
	var sb strings.Builder

	// add the values consistent across all commands
	sb.WriteString(fmt.Sprintf("vfxt.py --cloud-type azure --on-instance --instance-type %s --node-cache-size %d --azure-role '%s' --debug ",
		convertSku(avereVfxt.NodeSize),
		avereVfxt.NodeCacheSize,
		AverOperatorRole))

	// add the resource group and location
	sb.WriteString(fmt.Sprintf("--resource-group %s --location %s ", a.ResourceGroup, a.Location))

	// add the management address if one exists
	if len(avereVfxt.ManagementIP) > 0 {
		sb.WriteString(fmt.Sprintf("--management-address %s ", avereVfxt.ManagementIP))
	}

	// add the vnet subnet
	sb.WriteString(fmt.Sprintf("--network-resource-group %s --azure-network %s --azure-subnet %s ", a.NetworkResourceGroup, a.NetworkName, a.SubnetName))

	if len(avereVfxt.ProxyUri) > 0 {
		sb.WriteString(fmt.Sprintf("--proxy-uri %s ", avereVfxt.ProxyUri))
	}

	if len(avereVfxt.ClusterProxyUri) > 0 {
		sb.WriteString(fmt.Sprintf("--cluster-proxy-uri %s ", avereVfxt.ClusterProxyUri))
	}

	if len(avereVfxt.ImageId) > 0 {
		sb.WriteString(fmt.Sprintf("--image-id \"%s\" ", avereVfxt.ImageId))
	}

	if len(avereVfxt.UserAssignedManagedIdentity) > 0 {
		sb.WriteString(fmt.Sprintf("--azure-identity \"%s\" ", avereVfxt.UserAssignedManagedIdentity))
	}

	// add the vfxt information
	sb.WriteString(fmt.Sprintf("--cluster-name %s --admin-password '%s' ", avereVfxt.AvereVfxtName, avereVfxt.AvereAdminPassword))

	if len(avereVfxt.AvereSshKeyData) > 0 {
		sb.WriteString(fmt.Sprintf("--ssh-key %s ", VfxtKeyPubFile))
	}

	return sb.String()
}

// used when multiple commands piped together
func getAzCliProxyExports(proxyUri string) string {
	if len(proxyUri) > 0 {
		return fmt.Sprintf(" export HTTPS_PROXY=\"%s\" && export NO_PROXY=\"169.254.169.254\" && ", proxyUri)
	}
	return ""
}

// used when single command
func getAzCliProxyExportsInline(proxyUri string) string {
	if len(proxyUri) > 0 {
		return fmt.Sprintf(" HTTPS_PROXY=\"%s\" NO_PROXY=\"169.254.169.254\" ", proxyUri)
	}
	return ""
}

func getAzCliVerifyLoginCommand(avereVfxt *AvereVfxt) string {
	return WrapCommandForLogging(fmt.Sprintf("test -f ~/.azure/azureProfile.json || (%s az login --identity)", getAzCliProxyExports(avereVfxt.ProxyUri)), AzCliLogFile)
}

func (a Azure) getAzCliDeleteNodeCommand(avereVfxt *AvereVfxt, nodeName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s az vm list -g %s -o tsv --query \"[?name=='%s'].id\" | xargs az vm delete -y --ids ", getAzCliProxyExports(avereVfxt.ProxyUri), a.ResourceGroup, nodeName), AzCliLogFile)
}

func (a Azure) getAzCliDeleteNicCommand(avereVfxt *AvereVfxt, nodeName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s az network nic list -g %s -o tsv --query \"[?starts_with(name,'%s-')].id\" | xargs az network nic delete --ids ", getAzCliProxyExports(avereVfxt.ProxyUri), a.ResourceGroup, nodeName), AzCliLogFile)
}

func (a Azure) getAzCliDeleteDisksCommand(avereVfxt *AvereVfxt, nodeName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s az disk list -g %s -o tsv --query \"[?starts_with(name,'%s-')].id\"| xargs az disk delete -y --ids ", getAzCliProxyExports(avereVfxt.ProxyUri), a.ResourceGroup, nodeName), AzCliLogFile)
}

func getAzCliGetSubscriptionIdCommand(avereVfxt *AvereVfxt) string {
	return WrapCommandForLogging(fmt.Sprintf("%s az account show --query \"id\"", getAzCliProxyExports(avereVfxt.ProxyUri)), AzCliLogFile)
}

func getAzCliGetStorageKeyCommandRaw(accountName string) string {
	return fmt.Sprintf(" az storage account keys list --account-name %s --query \"[0].value\" ", accountName)
}

func getAzCliGetStorageAuthKeyCommand(avereVfxt *AvereVfxt, accountName string) string {
	return fmt.Sprintf(" --auth-mode key --account-key $(%s %s) ", getAzCliProxyExportsInline(avereVfxt.ProxyUri), getAzCliGetStorageKeyCommandRaw(accountName))
}

func getAzCliGetStorageKeyCommand(avereVfxt *AvereVfxt, accountName string) string {
	return WrapCommandForLoggingSecretOutput(fmt.Sprintf("%s %s", getAzCliProxyExports(avereVfxt.ProxyUri), getAzCliGetStorageKeyCommandRaw(accountName)), AzCliLogFile)
}

func getAzCliCreateStorageContainerCommand(avereVfxt *AvereVfxt, accountName string, container string) string {
	// data plane does not use proxy, the avere vfxt goes directly to the storage account, so the controller should also go directly there
	return WrapCommandForLogging(fmt.Sprintf("az storage container create --account-name %s --name %s %s", accountName, container, getAzCliGetStorageAuthKeyCommand(avereVfxt, accountName)), AzCliLogFile)
}

func getAzCliContainerExistsCommand(avereVfxt *AvereVfxt, accountName string, container string) string {
	// data plane does not use proxy, the avere vfxt goes directly to the storage account, so the controller should also go directly there
	return WrapCommandForLogging(fmt.Sprintf("az storage container exists --account-name %s --name %s %s", accountName, container, getAzCliGetStorageAuthKeyCommand(avereVfxt, accountName)), AzCliLogFile)
}

func getAzCliListFirstBlobCommand(avereVfxt *AvereVfxt, accountName string, container string) string {
	// data plane does not use proxy, the avere vfxt goes directly to the storage account, so the controller should also go directly there
	return WrapCommandForLogging(fmt.Sprintf("az storage blob list --account-name %s --container-name %s --num-results 1 --query \"[].name\" %s", accountName, container, getAzCliGetStorageAuthKeyCommand(avereVfxt, accountName)), AzCliLogFile)
}

// isVfxtNotFoundReported returns true if vfxt.py reports vfxt no found
func isVfxtNotFoundReported(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer) bool {
	resultStr := GetErrorMatches(stdoutBuf, stderrBuf, matchVfxtNotFound)
	return len(resultStr) > 0
}

// getAllErrors returns all errors encountered running vfxt.py
func getAllVfxtErrors(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer) string {
	var sb strings.Builder

	sb.WriteString(GetErrorMatches(stdoutBuf, stderrBuf, matchCreateFailure))
	sb.WriteString(GetErrorMatches(stdoutBuf, stderrBuf, matchVfxtFailure))

	return sb.String()
}

func getLastManagementIPAddress(stderrBuf bytes.Buffer) (string, error) {
	lastManagementIPAddr := getLastVfxtValue(stderrBuf, matchManagementIPAddressRegex)
	if len(lastManagementIPAddr) == 0 {
		lastManagementIPAddr = getLastVfxtValue(stderrBuf, matchManagementIPAddressRegex2)
		if len(lastManagementIPAddr) == 0 {
			return "", fmt.Errorf("ERROR: management ip address not found in vfxt.py output")
		}
	}
	return lastManagementIPAddr, nil
}

func getLastVfxtValue(stderrBuf bytes.Buffer, vfxtRegex *regexp.Regexp) string {
	var lastVfxtAddr string

	r := bytes.NewReader(stderrBuf.Bytes())
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		if matches := vfxtRegex.FindAllStringSubmatch(scanner.Text(), -1); matches != nil {
			if len(matches) > 0 && len(matches[0]) > 1 {
				lastVfxtAddr = matches[0][1]
			}
		}
	}
	return lastVfxtAddr
}

func convertSku(sku string) string {
	if sku == ClusterSkuUnsupportedTest {
		return AvereInstanceD16s
	}
	return AvereInstanceE32s
}
