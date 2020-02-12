// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"regexp"
	"strings"
	"time"

	"golang.org/x/crypto/ssh"
)

const (
	AvereInstanceType = "Standard_E32s_v3"
	AvereAdminUsername = "admin"
	NodeCacheSize     = 4096
	AverOperatorRole  = "Avere Operator"
	MinNodesToAdd     = 1
	// can't add more than 3 nodes at a time
	MaxNodesToAdd         = 3
	VfxtLogDateFormat     = "2006-01-02.15.04.05"
	VServerRangeSeperator = "-"
	AverecmdRetryCount = 12
	AverecmdRetrySleepSeconds = 10
	AverecmdLogFile = "~/averecmd.log"

	// cache policies
	CachePolicyClientsBypass = "Clients Bypassing the Cluster"
	CachePolicyReadCaching = "Read Caching"
	CachePolicyReadWriteCaching = "Read and Write Caching"
	CachePolicyFullCaching = "Full Caching"
	CachePolicyTransitioningClients = "Transitioning Clients Before or After a Migration"

	// filer class
	FilerClassNetappNonClustered = "NetappNonClustered"
	FilerClassNetappClustered = "NetappClustered"
	FilerClassEMCIsilon = "EmcIsilon"
	FilerClassOther = "Other"

	// filer retry 
	FilerRetryCount = 120
	FilerRetrySleepSeconds = 10
)

// matching strings for the vfxt.py output
var	matchManagementIPAddressRegex = regexp.MustCompile(` management address: (\d+.\d+.\d+.\d+)`)
var matchAvereOSVersionRegex = regexp.MustCompile(` version (AvereOS_V[^\s]*)`)
var	matchNodesRegex = regexp.MustCompile(` nodes: ([^\n]*)`)
var matchVServerIPRangeRegex = regexp.MustCompile(` - vFXT.cluster:INFO - Creating vserver vserver \(([^-]*-[^/]*)`)
var	matchCreateFailure = regexp.MustCompile(`^(.*vfxt:ERROR.*)$`)
var	matchVfxtFailure = regexp.MustCompile(`^(.*vFXTCreateFailure:.*)$`)
var matchVfxtNotFound = regexp.MustCompile(`(vfxt:ERROR - Cluster not found)`)
var matchWrongCheckCode = regexp.MustCompile(`(wrong check code)`)
var matchWrongNumberOfArgs = regexp.MustCompile(`(Wrong number of arguments)`)
var matchLoginFailed = regexp.MustCompile(`(login for user admin failed)`)
var matchMethodNotSupported = regexp.MustCompile(`(Method Not Supported)`)
var matchMustRemoveRelatedJunction = regexp.MustCompile(`(You must remove the related junction.s. before you can remove this core filer)`)

type CoreFiler struct {
	Name string `json:"name"`
	FqdnOrPrimaryIp string `json:"networkName"`
	CachePolicy string `json:"policyName"`
	InternalName string `json:"internalName"`
	FilerClass string `json:"filerClass"`
	AdminState string `json:"adminState"`
}

type AvereVfxt struct {
	ControllerAddress string
	ControllerUsename string

	SshAuthMethod ssh.AuthMethod

	ResourceGroup string
	Location      string

	/*NEED PROXY INFO*/

	AvereVfxtName      string
	AvereAdminPassword string
	NodeCount          int

	NetworkResourceGroup string
	NetworkName          string
	SubnetName           string

	// populated during creation
	AvereOSVersion     string
	ManagementIP       string
	VServerIPAddresses *[]string
	NodeNames          *[]string
}

// NewAvereVfxt creates new AvereVfxt
func NewAvereVfxt(
	controllerAddress string,
	controllerUsername string,
	sshAuthMethod ssh.AuthMethod,
	resourceGroup string,
	location string,
	avereVfxtName string,
	avereAdminPassword string,
	nodeCount int,
	networkResourceGroup string,
	networkName string,
	subnetName string,
	avereOSVersion string,
	managementIP string,
	vServerIPAddresses *[]string,
	nodeNames *[]string) *AvereVfxt {
	return &AvereVfxt{
		ControllerAddress:    controllerAddress,
		ControllerUsename:    controllerUsername,
		SshAuthMethod:        sshAuthMethod,
		ResourceGroup:        resourceGroup,
		Location:             location,
		AvereVfxtName:        avereVfxtName,
		AvereAdminPassword:   avereAdminPassword,
		NodeCount:            nodeCount,
		NetworkResourceGroup: networkResourceGroup,
		NetworkName:          networkName,
		SubnetName:           subnetName,
		AvereOSVersion: avereOSVersion,
		ManagementIP: managementIP,
		VServerIPAddresses: vServerIPAddresses,
		NodeNames: nodeNames,
	}
}

func (a *AvereVfxt) CreateVfxt() error {
	cmd := a.getCreateVfxtCommand()
	stdoutBuf, stderrBuf, err := SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, cmd)
	if err != nil {
		//allErrors := getAllVfxtErrors(stdoutBuf, stderrBuf)
		log.Printf("stdout: %s",stdoutBuf.String())
		return fmt.Errorf("Error creating vfxt: %v, from vfxt.py: '%s'", err, stderrBuf.String())
		//return fmt.Errorf("Error creating vfxt: %v, from vfxt.py: '%s'", err, allErrors)
	}

	avereOSversion, err := getLastAvereOSVersion(stderrBuf)
	if err != nil {
		return fmt.Errorf("Error creating vfxt: %s", err)
	}
	a.AvereOSVersion = avereOSversion

	mgmtIP, err := getLastManagementIPAddress(stderrBuf)
	if err != nil {
		return fmt.Errorf("Error creating vfxt: %s", err)
	}
	a.ManagementIP = mgmtIP

	vserverIpRange, err := getLastVServerIPRange(stderrBuf)
	if err != nil {
		return fmt.Errorf("Error creating vfxt: %s", err)
	}
	a.VServerIPAddresses = getVServerIPRange(vserverIpRange)

	nodes, err := getLastNodes(stderrBuf)
	if err != nil {
		return fmt.Errorf("Error creating vfxt: %s", err)
	}
	nodeNamesRaw := strings.Split(nodes, " ")
	a.NodeNames = &(nodeNamesRaw)

	return nil
}

func (a *AvereVfxt) DestroyVfxt() error {
	if len(a.ManagementIP) == 0 {
		return nil
	}
	cmd := a.getDestroyVfxtCommand()
	stdoutBuf, stderrBuf, err := SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, cmd)
	if err != nil && !isVfxtNotFoundReported(stdoutBuf, stderrBuf) {
		allErrors := getAllVfxtErrors(stdoutBuf, stderrBuf)
		return fmt.Errorf("Error destroying vfxt: %v, from vfxt.py: '%s'", err, allErrors)
	}
	a.AvereOSVersion = ""
	a.ManagementIP = ""
	a.VServerIPAddresses = &([]string{})
	a.NodeNames = &([]string{})

	return nil
}

func (a *AvereVfxt) ApplyCustomSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getSetCustomSettingCommand(customSetting))
	return err
}

func (a *AvereVfxt) RemoveCustomSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getRemoveCustomSettingCommand(customSetting))
	return err
}

func (a *AvereVfxt) GetExistingFilers() (map[string]*CoreFiler, error) {
	coreFilers, err := a.GetExistingFilerNames()
	if err != nil {
		return nil, err
	}
	results := make(map[string]*CoreFiler)
	for _, filer := range coreFilers {
		result, err := a.GetFiler(filer)
		if err != nil {
			return nil, fmt.Errorf("Error retrieving filer %s: %v", filer, err)
		}
		results[filer] = result
	}
	return results, nil
}

func (a *AvereVfxt) GetExistingFilerNames() ([]string, error) {
	coreFilersJson, err := a.AvereCommand(a.getListCoreFilersJsonCommand())
	if err != nil {
		return nil, err
	}
	var results []string
	if err := json.Unmarshal([]byte(coreFilersJson), &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) GetFiler(filer string) (*CoreFiler, error) {
	coreFilerJson, err := a.AvereCommand(a.getFilerJsonCommand(filer))
	if err != nil {
		return nil, err
	}
	var result map[string]CoreFiler
	if err := json.Unmarshal([]byte(coreFilerJson), &result); err != nil {
		return nil, err
	}
	coreFiler := result[filer]
	return &coreFiler, nil
}

func (a* AvereVfxt) CreateCoreFiler(corefiler *CoreFiler) error {
	_, err := a.AvereCommand(a.getCreateFilerCommand(corefiler))
	return err
}

func (a* AvereVfxt) DeleteCoreFiler(corefilerName string) error {
	_, err := a.AvereCommand(a.getDeleteFilerCommand(corefilerName))
	if err != nil {
		return err
	}
	for retries:=0 ; ; retries++ {
		coreFilers, err := a.GetExistingFilerNames()
		if err != nil {
			return err
		}

		exists := false
		for _, filer := range coreFilers {
			if filer == corefilerName {
				exists = true
				break
			}
		}
		if !exists {
			// the filer has been deleted
			return nil
		}

		if retries > FilerRetryCount {
			return fmt.Errorf("Failure to delete after %d retries trying to delete filer %s", retries, corefilerName)
		}
		time.Sleep(FilerRetrySleepSeconds * time.Second)
	}
}

func (a *AvereVfxt) AvereCommand(cmd string) (string, error) {
	var result string
	for retries:=0 ; ; retries++ {
		stdoutBuf, stderrBuf, err := SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, cmd)
		if err == nil {
			// success
			result = stdoutBuf.String()
			break
		}
		if isAverecmdNotRetryable(stdoutBuf, stderrBuf) {
			// failure not retryable
			return "", fmt.Errorf("Non retryable error applying command: '%s' '%s'", stdoutBuf.String(), stderrBuf.String()) 
		}
		if retries > AverecmdRetryCount {
			// failure after exhausted retries
			return "", fmt.Errorf("Failure after %d retries applying command: '%s' '%s'", retries, stdoutBuf.String(), stderrBuf.String()) 
		}
		time.Sleep(AverecmdRetrySleepSeconds * time.Second)
	}
	return result, nil
}

// no change can be made to the core parameters of the existing filers
func EnsureNoCoreAttributeChangeForExistingFilers(oldFiler map[string]*CoreFiler, newFiler map[string]*CoreFiler) error {
	for k, new := range newFiler {
		old, ok := oldFiler[k]
		if !ok {
			// no change since the core filer didn't previously exist
			continue
		}
		if old.FqdnOrPrimaryIp != new.FqdnOrPrimaryIp {
			return fmt.Errorf("Error: the fqdn or ip changed for filer '%s'.  To change delete the filer, and re-add", k)
		}
		if old.CachePolicy != new.CachePolicy {
			return fmt.Errorf("Error: the cache policy changed for filer '%s'.  To change delete the filer, and re-add", k)
		}
	}
	return nil
}

func (a *AvereVfxt) getCreateVfxtCommand() string {
	return fmt.Sprintf("%s --create --no-corefiler --nodes %d", a.getBaseVfxtCommand(), a.NodeCount)
}

func (a *AvereVfxt) getDestroyVfxtCommand() string {
	return fmt.Sprintf("%s --destroy", a.getBaseVfxtCommand())
}

func (a *AvereVfxt) getStartVfxtCommand() string {
	return fmt.Sprintf("%s --start", a.getBaseVfxtCommand())
}

func (a *AvereVfxt) getStopVfxtCommand() string {
	return fmt.Sprintf("%s --stop", a.getBaseVfxtCommand())
}

// the node count must be between 1 and 3
func (a *AvereVfxt) getAddNodesToVfxtCommand(newNodeCount int) (string, error) {
	if newNodeCount < MinNodesToAdd || newNodeCount > MaxNodesToAdd {
		return "", fmt.Errorf("Error: invalid nodes to add count %d.  vfxt.py requires the value to be between %d, and %d", newNodeCount, MinNodesToAdd, MaxNodesToAdd)
	}
	return fmt.Sprintf("%s --add-nodes --nodes %d", a.getBaseVfxtCommand(), newNodeCount), nil
}

func (a *AvereVfxt) getBaseVfxtCommand() string {
	var sb strings.Builder

	// add the values consistent across all commands
	sb.WriteString(fmt.Sprintf("vfxt.py --cloud-type azure --on-instance --instance-type %s --node-cache-size %d --azure-role '%s' --log ~/vfxt.%s.log --debug ",
		AvereInstanceType,
		NodeCacheSize,
		AverOperatorRole,
		time.Now().Format("2006-01-02-15.04.05")))

	// add the resource group and location
	sb.WriteString(fmt.Sprintf("--resource-group %s --location %s ", a.ResourceGroup, a.Location))

	// add the management address if one exists
	if len(a.ManagementIP) > 0 {
		sb.WriteString(fmt.Sprintf("--management-address %s ", a.ManagementIP))
	}

	// add the vnet subnet
	sb.WriteString(fmt.Sprintf("--network-resource-group %s --azure-network %s --azure-subnet %s ", a.NetworkResourceGroup, a.NetworkName, a.SubnetName))

	// add the vfxt information
	sb.WriteString(fmt.Sprintf("--cluster-name %s --admin-password '%s' ", a.AvereVfxtName, a.AvereAdminPassword))

	return sb.String()
}

func (a *AvereVfxt) getListCoreFilersJsonCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json corefiler.list", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getFilerJsonCommand(filer string) string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json corefiler.get %s", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateFilerCommand(coreFiler *CoreFiler) string {
	return wrapCommandForLogging(fmt.Sprintf("%s corefiler.create %s %s true \"{'filerNetwork':'cluster','filerClass':'Other','cachePolicy':'%s',}\"", a.getBaseAvereCmd(), coreFiler.Name, coreFiler.FqdnOrPrimaryIp, coreFiler.CachePolicy), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteFilerCommand(filer string) string {
	return wrapCommandForLogging(fmt.Sprintf("%s corefiler.remove %s", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getSetCustomSettingCommand(customSetting string) string {
	return wrapCommandForLogging(fmt.Sprintf("%s support.setCustomSetting %s", a.getBaseAvereCmd(), customSetting), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveCustomSettingCommand(customSetting string) string {
	firstArgument := strings.Split(customSetting, " ")[0]
	return wrapCommandForLogging(fmt.Sprintf("%s support.removeCustomSetting %s", a.getBaseAvereCmd(), firstArgument), AverecmdLogFile)
}

func wrapCommandForLogging(cmd string, outputfile string) string {
	return fmt.Sprintf("echo $(date) '%s' | sed 's/--password [^ ]*/--admin-password ***/' >> %s && %s 1> >(tee -a %s) 2> >(tee -a %s >&2)", cmd, outputfile, cmd, outputfile, outputfile)
}

func (a *AvereVfxt) getBaseAvereCmd() string {
	return fmt.Sprintf("averecmd --server %s --no-check-certificate --user %s --password '%s'", a.ManagementIP, AvereAdminUsername, a.AvereAdminPassword)
}

func getVServerIPRange(vserverIpRange string) *[]string {
	rangeIPs := strings.Split(vserverIpRange, VServerRangeSeperator)
	if len(rangeIPs) != 2 {
		// something wrong with the parse, just set the result
		ipAddrs := make([]string, 1, 1)
		ipAddrs = append(ipAddrs, vserverIpRange)
		return &ipAddrs
	}
	ipAddrStart := net.ParseIP(rangeIPs[0]).To4()
	ipAddrEnd := net.ParseIP(rangeIPs[1]).To4()

	if ipAddrEnd[3] <= ipAddrStart[3] || (ipAddrEnd[3]-ipAddrStart[3]) > 25 {
		// something wrong with the parse, just set the result
		ipAddrs := make([]string, 1, 1)
		ipAddrs = append(ipAddrs, vserverIpRange)
		return &ipAddrs
	}

	length := (ipAddrEnd[3] - ipAddrStart[3]) + 1
	ipAddrs := make([]string, 0, length)

	ipIncr := ipAddrStart
	for ipIncr[3] <= ipAddrEnd[3] {
		ipAddrs = append(ipAddrs, ipIncr.String())
		ipIncr[3]++
	}
	return &ipAddrs
}

func getLastManagementIPAddress(stderrBuf bytes.Buffer) (string, error) {
	lastManagementIPAddr := getLastVfxtValue(stderrBuf, matchManagementIPAddressRegex)
	if len(lastManagementIPAddr) == 0 {
		return "", fmt.Errorf("ERROR: management ip address not found in vfxt.py output")
	}
	return lastManagementIPAddr, nil
}

func getLastAvereOSVersion(stderrBuf bytes.Buffer) (string, error) {
	lastAvereOSVersion := getLastVfxtValue(stderrBuf, matchAvereOSVersionRegex)
	if len(lastAvereOSVersion) == 0 {
		return "", fmt.Errorf("ERROR: avereos version not found in vfxt.py output")
	}
	return lastAvereOSVersion, nil
}

func getLastNodes(stderrBuf bytes.Buffer) (string, error) {
	lastNodes := getLastVfxtValue(stderrBuf, matchNodesRegex)
	if len(lastNodes) == 0 {
		return "", fmt.Errorf("ERROR: nodes not found in vfxt.py output")
	}
	return lastNodes, nil
}

func getLastVServerIPRange(stderrBuf bytes.Buffer) (string, error) {
	lastVServerIPRange := getLastVfxtValue(stderrBuf, matchVServerIPRangeRegex)
	if len(lastVServerIPRange) == 0 {
		return "", fmt.Errorf("ERROR: VServer IP range not found in vfxt.py output")
	}
	return lastVServerIPRange, nil
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

// isVfxtNotFoundReported returns true if vfxt.py reports vfxt no found
func isVfxtNotFoundReported(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer) bool {
	resultStr := getErrors(stdoutBuf, stderrBuf, matchVfxtNotFound)
	return len(resultStr) > 0
}

// getAllErrors returns all errors encountered running vfxt.py
func getAllVfxtErrors(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer) string {
	var sb strings.Builder

	sb.WriteString(getErrors(stdoutBuf, stderrBuf, matchCreateFailure))
	sb.WriteString(getErrors(stdoutBuf, stderrBuf, matchVfxtFailure))

	return sb.String()
}

func isAverecmdNotRetryable(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer) bool {
	if len(getErrors(stdoutBuf, stderrBuf, matchWrongCheckCode)) > 0 {
		return true
	}
	if len(getErrors(stdoutBuf, stderrBuf, matchWrongNumberOfArgs)) > 0 {
		return true
	}
	if len(getErrors(stdoutBuf, stderrBuf, matchLoginFailed)) > 0 {
		return true
	}
	if len(getErrors(stdoutBuf, stderrBuf, matchMethodNotSupported)) > 0 {
		return true
	}
	if len(getErrors(stdoutBuf, stderrBuf, matchMustRemoveRelatedJunction)) > 0 {
		return true
	}
	return false
}

func getErrors(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer, errorRegex *regexp.Regexp) string {
	var sb strings.Builder

	r := bytes.NewReader(stdoutBuf.Bytes())
	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		if matches := errorRegex.FindStringSubmatch(scanner.Text()); matches != nil {
			if len(matches) > 1 {
				sb.WriteString(fmt.Sprintf("STDIN: %s\n", matches[1]))
			}
		}
	}

	r2 := bytes.NewReader(stderrBuf.Bytes())
	scanner2 := bufio.NewScanner(r2)
	for scanner2.Scan() {
		if matches := errorRegex.FindStringSubmatch(scanner2.Text()); matches != nil {
			if len(matches) > 1 {
				sb.WriteString(fmt.Sprintf("STDIN: %s\n", matches[1]))
			}
		}
	}

	return sb.String()
}
