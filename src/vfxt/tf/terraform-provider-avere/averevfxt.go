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
	"sort"
	"strings"
	"time"

	"golang.org/x/crypto/ssh"
)

// vfxt api documentation: https://azure.github.io/Avere/legacy/pdf/avere-os-5-1-xmlrpc-api-2019-01.pdf

const (
	AvereInstanceType = "Standard_E32s_v3"
	AvereAdminUsername = "admin"
	NodeCacheSize     = 4096
	AverOperatorRole  = "Avere Operator"
	MinNodesCount         = 3
	MaxNodesCount         = 16
	VfxtLogDateFormat     = "2006-01-02.15.04.05"
	VServerRangeSeperator = "-"
	AverecmdRetryCount = 30 // wait 5 minutes (ex. remove core filer gets perm denied for a while)
	AverecmdRetrySleepSeconds = 10
	AverecmdLogFile = "~/averecmd.log"
	AzCliLogFile = "~/azcli.log"
	VServerName = "vserver"

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

	// cluster stable, wait 40 minutes for cluster to become healthy
	ClusterStableRetryCount = 240
	ClusterStableRetrySleepSeconds = 10

	// node change, wait 40 minutes for node increase or decrease
	NodeChangeRetryCount = 240
	NodeChangeRetrySleepSeconds = 10

	// status's returned from Activity
	StatusComplete = "complete"
	StatusCompleted = "completed"
	StatusNodeRemoved = "node(s) removed"
	CompletedPercent = "100"
	NodeUp = "up"
	AlertSeverityGreen = "green" // this means the alert is complete
)

// matching strings for the vfxt.py output
var	matchManagementIPAddressRegex = regexp.MustCompile(` management address: (\d+.\d+.\d+.\d+)`)
var matchAvereOSVersionRegex = regexp.MustCompile(` version (AvereOS_V[^\s]*)`)
var	matchNodesRegex = regexp.MustCompile(` nodes: ([^\n]*)`)
var matchVServerIPRangeRegex = regexp.MustCompile(` - vFXT.cluster:INFO - Creating vserver vserver \(([^-]*-[^/]*)`)
var	matchCreateFailure = regexp.MustCompile(`^(.*vfxt:ERROR.*)$`)
var	matchVfxtFailure = regexp.MustCompile(`^(.*vFXTCreateFailure:.*)$`)
var matchVfxtNotFound = regexp.MustCompile(`(vfxt:ERROR - Cluster not found)`)

// non-retryable errors
var matchWrongCheckCode = regexp.MustCompile(`(wrong check code)`)
var matchWrongNumberOfArgs = regexp.MustCompile(`(Wrong number of arguments)`)
var matchLoginFailed = regexp.MustCompile(`(login for user admin failed)`)
var matchMethodNotSupported = regexp.MustCompile(`(Method Not Supported)`)
var matchMustRemoveRelatedJunction = regexp.MustCompile(`(You must remove the related junction.s. before you can remove this core filer)`)
var matchCannotFindMass = regexp.MustCompile(`('Cannot find MASS)`)
var matchJunctionNotFound = regexp.MustCompile(`(removeJunction failed.*'Cannot find junction)`)

type Node struct {
	Name string `json:"name"`
	State string `json:"state"`
}

type VServerClientIPHome struct {
	NodeName string `json:"current"`
	IPAddress string `json:"ip"`
}

type Activity struct {
	Id string `json:"id"`
	Status string `json:"status"`
	State string `json:"state"`
	Percent string `json:"percent"`
}

type Alert struct {
	Name string `json:"name"`
	Severity string `json:"severity"`
	Message string `json:"message"`
}

type CoreFiler struct {
	Name string `json:"name"`
	FqdnOrPrimaryIp string `json:"networkName"`
	CachePolicy string `json:"policyName"`
	InternalName string `json:"internalName"`
	FilerClass string `json:"filerClass"`
	AdminState string `json:"adminState"`
	CustomSettings []string
}

type Junction struct {
	NameSpacePath string `json:"path"`
	CoreFilerName string `json:"mass"`
	CoreFilerExport string `json:"export"`
}

type CustomSetting struct {
	Name string `json:"name"`
	Value string `json:"value"`
	CheckCode string `json:"checkCode"`
}

func initializeCustomSetting(customSettingString string) *CustomSetting {
	return &CustomSetting{
		Name:  getCustomSettingName(customSettingString),
		CheckCode: getCustomSettingCheckCode(customSettingString),
		Value: getCustomSettingValue(customSettingString),
	}
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

	ProxyUri string
	ClusterProxyUri string

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
	proxyUri string,
	clusterProxyUri string,
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
		ProxyUri:             proxyUri,
		ClusterProxyUri:      clusterProxyUri,
		AvereOSVersion: avereOSVersion,
		ManagementIP: managementIP,
		VServerIPAddresses: vServerIPAddresses,
		NodeNames: nodeNames,
	}
}

func (a *AvereVfxt) CreateVfxt() error {
	cmd := a.getCreateVfxtCommand()
	_, stderrBuf, err := SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, cmd)
	if err != nil {
		//allErrors := getAllVfxtErrors(stdoutBuf, stderrBuf)
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

func (a *AvereVfxt) ScaleCluster(newNodeCount int) error {
	if newNodeCount < MinNodesCount {
		return fmt.Errorf("Error: invalid scale size %d, cluster cannot have less than %d nodes", newNodeCount, MinNodesCount)
	}
	if newNodeCount > MaxNodesCount {
		return fmt.Errorf("Error: invalid scale size %d, cluster cannot have more than %d nodes", newNodeCount, MinNodesCount)
	}
	var err error
	if newNodeCount > a.NodeCount {
		// scale up the cluster
		log.Printf("scale up cluster %d=>%d", a.NodeCount, newNodeCount)
		err = a.scaleUpCluster(newNodeCount)
	} else {
		// scale down the cluster
		log.Printf("scale down cluster %d=>%d", a.NodeCount, newNodeCount)
		err = a.scaleDownCluster(newNodeCount)
	}
	currentNodeCount, err2 := a.GetCurrentNodeCount()
	if err2 != nil {
		if err != nil {
			return fmt.Errorf("two errors encountered resizing '%v', '%v'", err, err2)
		} else {
			return fmt.Errorf("error encountered while resizing '%v'", err2)
		}
	}
	a.NodeCount = currentNodeCount
	currentVServerIPAddresses, err2 := a.GetVServerIPAddresses()
	if err2 != nil {
		if err != nil {
			return fmt.Errorf("two errors encountered resizing '%v', '%v'", err, err2)
		} else {
			return fmt.Errorf("error encountered while resizing '%v'", err2)
		}
	}
	a.VServerIPAddresses = &currentVServerIPAddresses
	nodeNames, err2 := a.GetNodes()
	if err2 != nil {
		if err != nil {
			return fmt.Errorf("two errors encountered resizing '%v', '%v'", err, err2)
		} else {
			return fmt.Errorf("error encountered while resizing '%v'", err2)
		}
	}
	a.NodeNames = &nodeNames
	return err
}

func (a *AvereVfxt) GetLastNode() (string, error) {
	nodes, err := a.GetNodes()
	if err != nil {
		return "", err
	}
	if len(nodes) == 0 {
		return "", fmt.Errorf("no nodes found in the cluster")
	}

	sort.Sort(sort.Reverse(sort.StringSlice(nodes)))

	return nodes[0], nil
}

func (a *AvereVfxt) DeleteVfxtIaasNode(nodeName string) error {
	// verify logged in
	verifyLoginCommand := a.getAzCliVerifyLoginCommand()
	_, stderrBuf, err := SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, verifyLoginCommand)
	if err != nil {
		return fmt.Errorf("Error verifying login: %v, %s", err, stderrBuf.String())
	}
	// delete the node
	deleteNodeCommand := a.getAzCliDeleteNodeCommand(nodeName)
	_, stderrBuf, err = SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, deleteNodeCommand)
	if err != nil {
		return fmt.Errorf("Error deleting node: %v, %s", err, stderrBuf.String())
	}
	// delete the nic
	deleteNicCommand := a.getAzCliDeleteNicCommand(nodeName)
	_, stderrBuf, err = SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, deleteNicCommand)
	if err != nil {
		return fmt.Errorf("Error deleting nic: %v, %s", err, stderrBuf.String())
	}
	// delete the disks
	deleteDisksCommand := a.getAzCliDeleteDisksCommand(nodeName)
	_, stderrBuf, err = SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, deleteDisksCommand)
	if err != nil {
		return fmt.Errorf("Error deleting disks: %v, %s", err, stderrBuf.String())
	}
	return nil
}

func (a *AvereVfxt) CheckNodeExists(nodeName string) (bool, error) {
	nodes, err := a.GetNodes()
	if err != nil {
		return false, err
	}
	for _, v := range nodes {
		if v == nodeName {
			return true, nil
		}
	}
	return false, nil
}

func (a *AvereVfxt) GetCurrentNodeCount() (int, error) {
	nodes, err := a.GetNodes()
	if err != nil {
		return 0, err
	}
	return len(nodes), nil
}

func (a *AvereVfxt) GetNodes() ([]string, error) {
	coreNodesJson, err := a.AvereCommand(a.getListNodesJsonCommand())
	if err != nil {
		return nil, err
	}
	var results []string
	if err := json.Unmarshal([]byte(coreNodesJson), &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) GetExistingNodes() (map[string]*Node, error) {
	nodes, err := a.GetNodes()
	if err != nil {
		return nil, err
	}
	results := make(map[string]*Node)
	for _, node := range nodes {
		result, err := a.GetNode(node)
		if err != nil {
			return nil, fmt.Errorf("Error retrieving node %s: %v", node, err)
		}
		results[node] = result
	}
	return results, nil
}

func (a *AvereVfxt) GetNode(node string) (*Node, error) {
	coreNodeJson, err := a.AvereCommand(a.getNodeJsonCommand(node))
	if err != nil {
		return nil, err
	}
	var result map[string]Node
	if err := json.Unmarshal([]byte(coreNodeJson), &result); err != nil {
		return nil, err
	}
	nodeResult := result[node]
	return &nodeResult, nil
}

func (a *AvereVfxt) GetVServerIPAddresses() ([]string, error) {
	vserverClientIPHomeJson, err := a.AvereCommand(a.getVServerClientIPHomeJsonCommand())
	if err != nil {
		return nil, err
	}
	vServerClientIPHome := make([]VServerClientIPHome, 0)
	if err := json.Unmarshal([]byte(vserverClientIPHomeJson), &vServerClientIPHome); err != nil {
		return nil, err
	}
	ipAddresses := make([]net.IP, 0, len(vServerClientIPHome))
	for _, v := range vServerClientIPHome {
		ipAddresses = append(ipAddresses, net.ParseIP(v.IPAddress))
	}
	sort.Slice(ipAddresses, func(i, j int) bool {
		return bytes.Compare(ipAddresses[i], ipAddresses[j]) < 0
	})
	results := make([]string, 0, len(vServerClientIPHome))
	for _, v := range ipAddresses {
		results = append(results, v.String())
	}
	return results, nil
}

func (a *AvereVfxt) GetActivities() ([]Activity, error) {
	activitiesJson, err := a.AvereCommand(a.getClusterListActivitiesJsonCommand())
	if err != nil {
		return nil, err
	}
	var results []Activity
	if err := json.Unmarshal([]byte(activitiesJson), &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) GetAlerts() ([]Alert, error) {
	alertsJson, err := a.AvereCommand(a.getGetActiveAlertsJsonCommand())
	if err != nil {
		return nil, err
	}
	var results []Alert
	if err := json.Unmarshal([]byte(alertsJson), &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) EnsureClusterStable() (error) {
	for retries:=0 ; ; retries++ {

		healthy := true

		if healthy {
			// verify no activities
			activities, err := a.GetActivities()
			if err != nil {
				return err
			}
			for _, activity := range activities {
				switch activity.Status {
				case StatusComplete:
				case StatusCompleted:
				case StatusNodeRemoved:
					continue
				default:
					if activity.Percent != CompletedPercent {
						log.Printf("cluster still has running activity %v", activity)
						healthy = false
						break
					}
				}
			}
		}

		if healthy {
			// verify no active alerts
			alerts, err := a.GetAlerts()
			if err != nil {
				return err
			} 
			for _, alert := range alerts {
				if alert.Severity != AlertSeverityGreen {
					log.Printf("cluster still has active alert %v", alert)
					healthy = false
					break
				}
			}
		}
		
		if healthy {
			// verify all nodes healthy
			nodes, err := a.GetExistingNodes()
			if err != nil {
				return err
			}
			for _, node := range nodes {
				if node.State != NodeUp {
					healthy = false
					break
				}
			}
		}

		if healthy {
			// the cluster is stable
			return nil
		}

		if retries > ClusterStableRetryCount {
			return fmt.Errorf("Failure for cluster to become stable after %d retries", retries)
		}
		time.Sleep(ClusterStableRetrySleepSeconds * time.Second)
	}
}

func (a *AvereVfxt) CreateCustomSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getSetCustomSettingCommand(customSetting))
	return err
}

func (a *AvereVfxt) RemoveCustomSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getRemoveCustomSettingCommand(customSetting))
	return err
}

func (a *AvereVfxt) CreateVServerSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getSetVServerSettingCommand(customSetting))
	return err
}

func (a *AvereVfxt) RemoveVServerSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getRemoveVServerSettingCommand(customSetting))
	return err
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

func (a *AvereVfxt) GetCoreFilerCustomSettings(coreFileInternalName string) (map[string]*CustomSetting, error) {
	customSettings, err := a.GetCustomSettings()
	if err != nil {
		return nil, err
	}
	results := make(map[string]*CustomSetting, 0)
	prefix := fmt.Sprintf("%s.", coreFileInternalName)
	for _, v := range customSettings {
		customSetting := CustomSetting{}
		customSetting = *v
		// add the custom settings that have the prefix
		if strings.HasPrefix(customSetting.Name, prefix) {
			results[customSetting.Name] = &customSetting
		}
	}
	return results, nil
}

func (a *AvereVfxt) GetCustomSettings() (map[string]*CustomSetting, error) {
	customSettingsJson, err := a.AvereCommand(a.getListCustomSettingsJsonCommand())
	if err != nil {
		return nil, err
	}
	var resultRaw []CustomSetting
	if err := json.Unmarshal([]byte(customSettingsJson), &resultRaw); err != nil {
		return nil, err
	}
	results := make(map[string]*CustomSetting, 0)
	for _, v := range resultRaw {
		customSetting := CustomSetting{}
		customSetting = v
		results[customSetting.Name] = &customSetting
	}
	return results, nil
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

func (a* AvereVfxt) EnsureInternalName(corefiler *CoreFiler) error {
	// Ensure internal name
	if len(corefiler.InternalName) == 0 {
		// get the internal name
		newfiler, err := a.GetFiler(corefiler.Name)
		if err != nil {
			return err
		}
		// add the settings
		corefiler.InternalName = newfiler.InternalName
	}
	return nil
}

func (a* AvereVfxt) AddCoreFilerCustomSettings(corefiler *CoreFiler) error {
	// ensure the internal name exists
	a.EnsureInternalName(corefiler)
	if len(corefiler.CustomSettings) == 0 {
		// no custom settings to add
		return nil
	}

	// get the mass custom settings
	existingCustomSettings, err := a.GetCoreFilerCustomSettings(corefiler.InternalName)
	if err != nil {
		return err
	}

	// add the new settings
	for _, v := range corefiler.CustomSettings {
		customSettingName := getCustomSettingName(getCoreFilerCustomSettingName(corefiler.InternalName, v))
		if _, ok := existingCustomSettings[customSettingName] ; ok {
			// the custom setting already exists
			continue
		}
		if _, err := a.AvereCommand(a.getSetCoreFilerSettingCommand(corefiler, v)) ; err != nil{
			return err
		}
	}

	return nil
}

func (a* AvereVfxt) RemoveCoreFilerCustomSettings(corefiler *CoreFiler) error {
	// ensure the internal name exists
	a.EnsureInternalName(corefiler)
	
	// get the mass custom settings
	existingCustomSettings, err := a.GetCoreFilerCustomSettings(corefiler.InternalName)
	if err != nil {
		return err
	}
	
	newSettingsSet := make(map[string]*CustomSetting)
	for _, v := range corefiler.CustomSettings {
		customSettingStr := getCoreFilerCustomSettingName(corefiler.InternalName, v)
		newSettingsSet[getCustomSettingName(customSettingStr)] = initializeCustomSetting(customSettingStr)
	}
	
	// remove any that have changed or no longer exist
	for k, v := range existingCustomSettings {
		if _, ok := newSettingsSet[k] ; ok  {
			// due to the universal checkcode being different from the mass checkcode, only
			// compare name and value
			if (*v).Name == (*(newSettingsSet[k])).Name && (*v).Value == (*(newSettingsSet[k])).Value {
				// the setting still exists
				continue
			}			
		}
		if _, err := a.AvereCommand(a.getRemoveCoreFilerSettingCommand(corefiler, v.Name)) ; err != nil{
			return err
		}
	}

	return nil
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

func (a *AvereVfxt) GetExistingJunctions() (map[string]*Junction, error) {
	results := make(map[string]*Junction)
	coreJunctionsJson, err := a.AvereCommand(a.getListJunctionsJsonCommand())
	if err != nil {
		return nil, err
	}
	var jsonResults []Junction
	if err := json.Unmarshal([]byte(coreJunctionsJson), &jsonResults); err != nil {
		return nil, err
	}
	for _, v := range jsonResults {
		// create a new object to assign v
		newJunction := Junction{}
		newJunction = v
		results[v.NameSpacePath] = &newJunction
	}
	return results, nil
}

func (a* AvereVfxt) CreateJunction(junction *Junction) error {
	_, err := a.AvereCommand(a.getCreateJunctionCommand(junction))
	return err
}

func (a* AvereVfxt) DeleteJunction(junctionNameSpacePath string) error {
	_, err := a.AvereCommand(a.getDeleteJunctionCommand(junctionNameSpacePath))
	if err != nil {
		return err
	}
	for retries:=0 ; ; retries++ {
		junctions, err := a.GetExistingJunctions()
		if err != nil {
			return err
		}

		if _, ok := junctions[junctionNameSpacePath] ; !ok {
			// the junction is gone
			return nil
		}

		if retries > FilerRetryCount {
			return fmt.Errorf("Failure to delete after %d retries trying to delete junction %s", retries, junctionNameSpacePath)
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
			return "", fmt.Errorf("Failure after %d retries applying command: '%s' '%s'", AverecmdRetryCount, stdoutBuf.String(), stderrBuf.String()) 
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

// scale-up the cluster to the newNodeCount
func (a *AvereVfxt) scaleUpCluster(newNodeCount int) error {
	for {
		currentNodeCount, err := a.GetCurrentNodeCount()
		if err != nil {
			return err
		}
		// check if cluster sizing is complete
		if currentNodeCount >= newNodeCount {
			return nil
		}
		log.Printf("add node to cluster %d (target %d)", currentNodeCount, newNodeCount)
		err = a.addNodeToCluster(currentNodeCount)
		if err != nil {
			return err
		}
		log.Printf("ensure stable cluster")
		err = a.EnsureClusterStable()
		if err != nil {
			return err
		}
	}
}

// scale-down the cluster to the newNodeCount
func (a *AvereVfxt) scaleDownCluster(newNodeCount int) error {
	for {
		currentNodeCount, err := a.GetCurrentNodeCount()
		if err != nil {
			return err
		}
		// check if cluster sizing is complete
		if currentNodeCount <= newNodeCount {
			return nil
		}
		lastNode, err := a.GetLastNode()
		if err != nil {
			return err
		}
		if err = a.removeNodeFromCluster(lastNode, currentNodeCount) ; err != nil {
			return err
		}
		if err = a.EnsureClusterStable() ; err != nil {
			return err
		}
		// only delete the IaaS Node after the cluster is stable
		if err = a.DeleteVfxtIaasNode(lastNode) ; err != nil {
			return err
		}
	}
}

// add a new node to the cluster
func (a *AvereVfxt) addNodeToCluster(currentNodeCount int) error {
	// we may only add a single node at a time
	targetNodeCount := currentNodeCount + 1

	cmd := a.getAddNodeToVfxtCommand()
	_, stderrBuf, err := SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, cmd)
	if err != nil {
		return fmt.Errorf("Error adding node to vfxt: %v, from vfxt.py: '%s'", err, stderrBuf.String())
	}
	
	for retries:=0 ; ; retries++ {
		nodeCount, err := a.GetCurrentNodeCount()
		if err != nil {
			return err
		}
		if nodeCount >= targetNodeCount {
			// the node has been added
			return nil
		}
		if retries > NodeChangeRetryCount {
			return fmt.Errorf("Failure to add node after %d retries trying to add node", retries)
		}
		time.Sleep(NodeChangeRetrySleepSeconds * time.Second)
	}
}

// remove a new node to the cluster
func (a *AvereVfxt) removeNodeFromCluster(nodeName string, currentNodeCount int) error {
	// we may only remove a single node at a time
	targetNodeCount := currentNodeCount - 1

	_, err := a.AvereCommand(a.getRemoveNodeCommand(nodeName))
	if err != nil {
		return err
	}

	for retries:=0 ; ; retries++ {
		nodeCount, err := a.GetCurrentNodeCount()
		if err != nil {
			return err
		}
		if nodeCount <= targetNodeCount {
			// the node has been removed
			return nil
		}
		if retries > NodeChangeRetryCount {
			return fmt.Errorf("Failure to delete after %d retries trying to delete node", retries)
		}
		time.Sleep(NodeChangeRetrySleepSeconds * time.Second)
	}
}

func (a *AvereVfxt) getCreateVfxtCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --create --no-corefiler --nodes %d", a.getBaseVfxtCommand(), a.NodeCount), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a *AvereVfxt) getDestroyVfxtCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --destroy", a.getBaseVfxtCommand()), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a *AvereVfxt) getStartVfxtCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --start", a.getBaseVfxtCommand()), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a *AvereVfxt) getStopVfxtCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --stop", a.getBaseVfxtCommand()), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a *AvereVfxt) getAddNodeToVfxtCommand() string {
	// only adding one node at a time is stable
	return wrapCommandForLogging(fmt.Sprintf("%s --add-nodes --nodes 1", a.getBaseVfxtCommand()), fmt.Sprintf("~/vfxt.%s.log", time.Now().Format("2006-01-02-15.04.05")))
}

func (a *AvereVfxt) getBaseVfxtCommand() string {
	var sb strings.Builder

	// add the values consistent across all commands
	sb.WriteString(fmt.Sprintf("vfxt.py --cloud-type azure --on-instance --instance-type %s --node-cache-size %d --azure-role '%s' --debug ",
		AvereInstanceType,
		NodeCacheSize,
		AverOperatorRole))

	// add the resource group and location
	sb.WriteString(fmt.Sprintf("--resource-group %s --location %s ", a.ResourceGroup, a.Location))

	// add the management address if one exists
	if len(a.ManagementIP) > 0 {
		sb.WriteString(fmt.Sprintf("--management-address %s ", a.ManagementIP))
	}

	// add the vnet subnet
	sb.WriteString(fmt.Sprintf("--network-resource-group %s --azure-network %s --azure-subnet %s ", a.NetworkResourceGroup, a.NetworkName, a.SubnetName))

	if len(a.ProxyUri) > 0 {
		sb.WriteString(fmt.Sprintf("--proxy-uri %s ", a.ProxyUri))
	}

	if len(a.ClusterProxyUri) > 0 {
		sb.WriteString(fmt.Sprintf("--cluster-proxy-uri %s ", a.ClusterProxyUri))
	}

	// add the vfxt information
	sb.WriteString(fmt.Sprintf("--cluster-name %s --admin-password '%s' ", a.AvereVfxtName, a.AvereAdminPassword))

	return sb.String()
}

func (a *AvereVfxt) getListNodesJsonCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json node.list", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveNodeCommand(node string) string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json node.remove %s", a.getBaseAvereCmd(), node), AverecmdLogFile)
}

func (a *AvereVfxt) getNodeJsonCommand(node string) string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json node.get %s", a.getBaseAvereCmd(), node), AverecmdLogFile)
}

func (a *AvereVfxt) getClusterListActivitiesJsonCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json cluster.listActivities", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getGetActiveAlertsJsonCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json alert.getActive", a.getBaseAvereCmd()), AverecmdLogFile)
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

func (a *AvereVfxt) getVServerClientIPHomeJsonCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json vserver.listClientIPHomes %s", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getListJunctionsJsonCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json vserver.listJunctions %s", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateJunctionCommand(junction *Junction) string {
	return wrapCommandForLogging(fmt.Sprintf("%s vserver.addJunction %s %s %s %s \"{'sharesubdir':'','inheritPolicy':'yes','sharename':'','access':'posix','createSubdirs':'yes','subdir':'','policy':''}\"", a.getBaseAvereCmd(), VServerName, junction.NameSpacePath, junction.CoreFilerName, junction.CoreFilerExport), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteJunctionCommand(junctionNameSpacePath string) string {
	return wrapCommandForLogging(fmt.Sprintf("%s vserver.removeJunction %s %s", a.getBaseAvereCmd(), VServerName, junctionNameSpacePath), AverecmdLogFile)
}

func (a *AvereVfxt) getListCustomSettingsJsonCommand() string {
	return wrapCommandForLogging(fmt.Sprintf("%s --json support.listCustomSettings", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSetCustomSettingCommand(customSetting string) string {
	return wrapCommandForLogging(fmt.Sprintf("%s support.setCustomSetting %s", a.getBaseAvereCmd(), customSetting), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveCustomSettingCommand(customSetting string) string {
	firstArgument := getCustomSettingName(customSetting)
	return wrapCommandForLogging(fmt.Sprintf("%s support.removeCustomSetting %s", a.getBaseAvereCmd(), firstArgument), AverecmdLogFile)
}

func (a *AvereVfxt) getSetVServerSettingCommand(customSetting string) string {
	vServerCustomSetting := getVServerCustomSettingName(customSetting)
	return a.getSetCustomSettingCommand(vServerCustomSetting)
}

func (a *AvereVfxt) getRemoveVServerSettingCommand(customSetting string) string {
	vServerCustomSetting := getVServerCustomSettingName(customSetting)
	return a.getRemoveCustomSettingCommand(vServerCustomSetting)
}

func (a *AvereVfxt) getSetCoreFilerSettingCommand(corefiler *CoreFiler, customSetting string) string {
	coreFilerCustomSetting := getCoreFilerCustomSettingName(corefiler.InternalName, customSetting)
	return a.getSetCustomSettingCommand(coreFilerCustomSetting)
}

func (a *AvereVfxt) getRemoveCoreFilerSettingCommand(corefiler *CoreFiler, customSettingName string) string {
	return a.getRemoveCustomSettingCommand(customSettingName)
}

func getCustomSettingName(customSettingString string) string {
	return strings.Split(customSettingString, " ")[0]
}

func getCustomSettingCheckCode(customSettingString string) string {
	parts := strings.Split(customSettingString, " ")
	if len(parts) > 1 {
		return parts[1]
	}
	return ""
}

func getCustomSettingValue(customSettingString string) string {
	parts := strings.Split(customSettingString, " ")
	if len(parts) > 2 {
		var sb strings.Builder
		for i:=2; i < len(parts) ; i++ {
			sb.WriteString(fmt.Sprintf("%s ", parts[i]))
		}
		return strings.TrimSpace(sb.String())
	}
	return ""
}

func getVServerCustomSettingName(customSetting string) string {
	return fmt.Sprintf("%s1.%s", VServerName, customSetting)
}

func getCoreFilerCustomSettingName(internalName string, customSetting string) string {
	return fmt.Sprintf("%s.%s", internalName, customSetting) 
}

func wrapCommandForLogging(cmd string, outputfile string) string {
	return fmt.Sprintf("echo $(date) '%s' | sed 's/-password [^ ]*/-password ***/' >> %s && %s 1> >(tee -a %s) 2> >(tee -a %s >&2)", cmd, outputfile, cmd, outputfile, outputfile)
}

func (a *AvereVfxt) getBaseAvereCmd() string {
	return fmt.Sprintf("averecmd --server %s --no-check-certificate --user %s --password '%s'", a.ManagementIP, AvereAdminUsername, a.AvereAdminPassword)
}

func (a *AvereVfxt) getAzCliVerifyLoginCommand() string {
	return wrapCommandForLogging("test -f ~/.azure/azureProfile.json || az login --identity", AzCliLogFile)
}

func (a *AvereVfxt) getAzCliDeleteNodeCommand(nodeName string) string {
	return wrapCommandForLogging(fmt.Sprintf("az vm list -g %s -o tsv --query \"[?name=='%s'].id\" | xargs az vm delete -y --ids ", a.ResourceGroup, nodeName), AzCliLogFile)
}

func (a *AvereVfxt) getAzCliDeleteNicCommand(nodeName string) string {
	return wrapCommandForLogging(fmt.Sprintf("az network nic list -g %s -o tsv --query \"[?starts_with(name,'%s-')].id\" | xargs az network nic delete --ids ", a.ResourceGroup, nodeName), AzCliLogFile)
}

func (a *AvereVfxt) getAzCliDeleteDisksCommand(nodeName string) string {
	return wrapCommandForLogging(fmt.Sprintf("az disk list -g %s -o tsv --query \"[?starts_with(name,'%s-')].id\"| xargs az disk delete -y --ids ", a.ResourceGroup, nodeName), AzCliLogFile)
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
	if len(getErrors(stdoutBuf, stderrBuf, matchCannotFindMass)) > 0 {
		return true
	}
	if len(getErrors(stdoutBuf, stderrBuf, matchJunctionNotFound)) > 0 {
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
