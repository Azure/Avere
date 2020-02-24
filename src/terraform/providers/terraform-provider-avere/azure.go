// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/hashicorp/terraform-plugin-sdk/helper/schema"
)

// Azure specific constants
const (
	AzCliLogFile        = "~/azcli.log"
	AzLoginRetryCount   = 18 // wait 3 minutes
	AzLoginSleepSeconds = 10
	AvereInstanceType   = "Standard_E32s_v3"
	AverOperatorRole    = "Avere Operator"
	NodeCacheSize       = 4096
)

type Azure struct {
	ResourceGroup        string
	Location             string
	NetworkResourceGroup string
	NetworkName          string
	SubnetName           string
}

// matching strings for the vfxt.py output
var matchManagementIPAddressRegex = regexp.MustCompile(` management address: (\d+.\d+.\d+.\d+)`)
var matchCreateFailure = regexp.MustCompile(`^(.*vfxt:ERROR.*)$`)
var matchVfxtFailure = regexp.MustCompile(`^(.*vFXTCreateFailure:.*)$`)
var matchVfxtNotFound = regexp.MustCompile(`(vfxt:ERROR - Cluster not found)`)

func NewAzureIaasPlatform(d *schema.ResourceData) (IaasPlatform, error) {
	// confirm rg and vnet subnet values were set as these are specified
	// as optional
	if _, ok := d.GetOk("azure_resource_group"); !ok {
		return nil, fmt.Errorf("Error: 'azure_resource_group is not set")
	}
	if _, ok := d.GetOk("azure_network_resource_group"); !ok {
		return nil, fmt.Errorf("Error: 'azure_network_resource_group is not set")
	}
	if _, ok := d.GetOk("azure_network_name"); !ok {
		return nil, fmt.Errorf("Error: 'azure_network_name is not set")
	}
	if _, ok := d.GetOk("azure_subnet_name"); !ok {
		return nil, fmt.Errorf("Error: 'azure_subnet_name is not set")
	}
	return Azure{
		ResourceGroup:        d.Get("azure_resource_group").(string),
		Location:             d.Get("location").(string),
		NetworkResourceGroup: d.Get("azure_network_resource_group").(string),
		NetworkName:          d.Get("azure_network_name").(string),
		SubnetName:           d.Get("azure_subnet_name").(string),
	}, nil
}

func (a Azure) CreateVfxt(avereVfxt *AvereVfxt) error {
	// verify az logged in
	if err := a.verifyAzLogin(avereVfxt); err != nil {
		return fmt.Errorf("Error verifying az cli login: %v", err)
	}
	cmd := a.getCreateVfxtCommand(avereVfxt)
	stdoutBuf, stderrBuf, err := SSHCommand(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, cmd)
	if err != nil {
		allErrors := getAllVfxtErrors(stdoutBuf, stderrBuf)
		return fmt.Errorf("Error creating vfxt: %v, from vfxt.py: '%s'", err, allErrors)
	}

	mgmtIP, err := getLastManagementIPAddress(stderrBuf)
	if err != nil {
		return fmt.Errorf("Error creating vfxt: %s", err)
	}
	avereVfxt.ManagementIP = mgmtIP

	return nil
}

func (a Azure) AddIaasNodeToCluster(avereVfxt *AvereVfxt) error {
	cmd := a.getAddNodeToVfxtCommand(avereVfxt)
	if _, stderrBuf, err := SSHCommand(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, cmd); err != nil {
		return fmt.Errorf("Error adding node to vfxt: %v, from vfxt.py: '%s'", err, stderrBuf.String())
	}

	return nil
}

func (a Azure) DestroyVfxt(avereVfxt *AvereVfxt) error {
	if len(avereVfxt.ManagementIP) == 0 {
		return nil
	}
	cmd := a.getDestroyVfxtCommand(avereVfxt)
	stdoutBuf, stderrBuf, err := SSHCommand(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, cmd)
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
	// verify az logged in
	if err := a.verifyAzLogin(avereVfxt); err != nil {
		return fmt.Errorf("Error verifying login: %v", err)
	}
	// delete the node
	deleteNodeCommand := a.getAzCliDeleteNodeCommand(nodeName)
	_, stderrBuf, err := SSHCommand(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, deleteNodeCommand)
	if err != nil {
		return fmt.Errorf("Error deleting node: %v, %s", err, stderrBuf.String())
	}
	// delete the nic
	deleteNicCommand := a.getAzCliDeleteNicCommand(nodeName)
	_, stderrBuf, err = SSHCommand(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, deleteNicCommand)
	if err != nil {
		return fmt.Errorf("Error deleting nic: %v, %s", err, stderrBuf.String())
	}
	// delete the disks
	deleteDisksCommand := a.getAzCliDeleteDisksCommand(nodeName)
	_, stderrBuf, err = SSHCommand(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, deleteDisksCommand)
	if err != nil {
		return fmt.Errorf("Error deleting disks: %v, %s", err, stderrBuf.String())
	}
	return nil
}

// the auth for Azure uses the managed identity of the controller to run Azure
// cli commands.  VerifyPlatformAuth confirms that the auth was setup
// correctly
func (a Azure) verifyAzLogin(avereVfxt *AvereVfxt) error {
	// it can take a while for the IMDS roles to propagate, retry until login succeeds
	verifyLoginCommand := getAzCliVerifyLoginCommand()
	var err error
	err = nil
	for retries := 0; retries < AzLoginRetryCount; retries++ {
		if _, _, err = SSHCommand(avereVfxt.ControllerAddress, avereVfxt.ControllerUsename, avereVfxt.SshAuthMethod, verifyLoginCommand); err == nil {
			// success
			err = nil
			break
		}
		time.Sleep(AzLoginSleepSeconds * time.Second)
	}
	return err
}

func (a Azure) getCreateVfxtCommand(avereVfxt *AvereVfxt) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --create --no-corefiler --nodes %d", a.getBaseVfxtCommand(avereVfxt), avereVfxt.NodeCount), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
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
		AvereInstanceType,
		NodeCacheSize,
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

	// add the vfxt information
	sb.WriteString(fmt.Sprintf("--cluster-name %s --admin-password '%s' ", avereVfxt.AvereVfxtName, avereVfxt.AvereAdminPassword))

	return sb.String()
}

func getAzCliVerifyLoginCommand() string {
	return WrapCommandForLogging("test -f ~/.azure/azureProfile.json || az login --identity", AzCliLogFile)
}

func (a Azure) getAzCliDeleteNodeCommand(nodeName string) string {
	return WrapCommandForLogging(fmt.Sprintf("az vm list -g %s -o tsv --query \"[?name=='%s'].id\" | xargs az vm delete -y --ids ", a.ResourceGroup, nodeName), AzCliLogFile)
}

func (a Azure) getAzCliDeleteNicCommand(nodeName string) string {
	return WrapCommandForLogging(fmt.Sprintf("az network nic list -g %s -o tsv --query \"[?starts_with(name,'%s-')].id\" | xargs az network nic delete --ids ", a.ResourceGroup, nodeName), AzCliLogFile)
}

func (a Azure) getAzCliDeleteDisksCommand(nodeName string) string {
	return WrapCommandForLogging(fmt.Sprintf("az disk list -g %s -o tsv --query \"[?starts_with(name,'%s-')].id\"| xargs az disk delete -y --ids ", a.ResourceGroup, nodeName), AzCliLogFile)
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
		return "", fmt.Errorf("ERROR: management ip address not found in vfxt.py output")
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
