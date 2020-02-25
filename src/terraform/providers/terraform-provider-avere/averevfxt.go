// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
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

// non-retryable errors from averecmd
var matchWrongCheckCode = regexp.MustCompile(`(wrong check code)`)
var matchWrongNumberOfArgs = regexp.MustCompile(`(Wrong number of arguments)`)
var matchLoginFailed = regexp.MustCompile(`(1login for user admin failed)`)
var matchMethodNotSupported = regexp.MustCompile(`(Method Not Supported)`)
var matchMustRemoveRelatedJunction = regexp.MustCompile(`(You must remove the related junction.s. before you can remove this core filer)`)
var matchCannotFindMass = regexp.MustCompile(`('Cannot find MASS)`)
var matchJunctionNotFound = regexp.MustCompile(`(removeJunction failed.*'Cannot find junction)`)

func initializeCustomSetting(customSettingString string) *CustomSetting {
	return &CustomSetting{
		Name:      getCustomSettingName(customSettingString),
		CheckCode: getCustomSettingCheckCode(customSettingString),
		Value:     getCustomSettingValue(customSettingString),
	}
}

func (c *CustomSetting) GetCustomSettingCommand() string {
	return fmt.Sprintf("%s %s %s", c.Name, c.CheckCode, c.Value)
}

// NewAvereVfxt creates new AvereVfxt
func NewAvereVfxt(
	controllerAddress string,
	controllerUsername string,
	sshAuthMethod ssh.AuthMethod,
	platform IaasPlatform,
	avereVfxtName string,
	avereAdminPassword string,
	nodeCount int,
	proxyUri string,
	clusterProxyUri string,
	managementIP string,
	vServerIPAddresses *[]string,
	nodeNames *[]string) *AvereVfxt {
	return &AvereVfxt{
		ControllerAddress:  controllerAddress,
		ControllerUsename:  controllerUsername,
		SshAuthMethod:      sshAuthMethod,
		Platform:           platform,
		AvereVfxtName:      avereVfxtName,
		AvereAdminPassword: avereAdminPassword,
		NodeCount:          nodeCount,
		ProxyUri:           proxyUri,
		ClusterProxyUri:    clusterProxyUri,
		ManagementIP:       managementIP,
		VServerIPAddresses: vServerIPAddresses,
		NodeNames:          nodeNames,
	}
}

func (a *AvereVfxt) ScaleCluster(previousNodeCount int, newNodeCount int) error {
	if newNodeCount < MinNodesCount {
		return fmt.Errorf("Error: invalid scale size %d, cluster cannot have less than %d nodes", newNodeCount, MinNodesCount)
	}
	if newNodeCount > MaxNodesCount {
		return fmt.Errorf("Error: invalid scale size %d, cluster cannot have more than %d nodes", newNodeCount, MaxNodesCount)
	}

	if newNodeCount > previousNodeCount {
		// scale up the cluster
		log.Printf("[INFO] vfxt: scale up cluster %d=>%d", previousNodeCount, newNodeCount)
		if err := a.scaleUpCluster(newNodeCount); err != nil {
			return fmt.Errorf("error encountered while scaling up '%v'", err)
		}
	} else {
		// scale down the cluster
		log.Printf("[INFO] vfxt: scale down cluster %d=>%d", previousNodeCount, newNodeCount)
		if err := a.scaleDownCluster(newNodeCount); err != nil {
			return fmt.Errorf("error encountered while scaling down '%v'", err)
		}
	}

	return nil
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

func (a *AvereVfxt) EnsureClusterStable() error {
	for retries := 0; ; retries++ {

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
						log.Printf("[INFO] vfxt: cluster still has running activity %v", activity)
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
				// ignore green and yellow alerts
				if alert.Severity != AlertSeverityGreen && alert.Severity != AlertSeverityYellow {
					log.Printf("[WARN] [%d/%d] vfxt: cluster still has active alert %v", retries, ClusterStableRetryCount, alert)
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
					log.Printf("[WARN] [%d/%d] node %v not up and in state %v", retries, ClusterStableRetryCount, node, node.State)
					healthy = false
					break
				}
			}
		}

		if healthy {
			// the cluster is stable
			break
		}

		if retries > ClusterStableRetryCount {
			return fmt.Errorf("Failure for cluster to become stable after %d retries", retries)
		}
		time.Sleep(ClusterStableRetrySleepSeconds * time.Second)
	}
	return nil
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

func (a *AvereVfxt) ListExports(filer string) ([]NFSExport, error) {
	exports, err := a.AvereCommand(a.getListCoreFilerExportsJsonCommand(filer))
	if err != nil {
		return nil, err
	}
	var resultRaw map[string][]NFSExport
	if err := json.Unmarshal([]byte(exports), &resultRaw); err != nil {
		return nil, err
	}
	result, ok := resultRaw[filer]
	if !ok {
		return nil, fmt.Errorf("Error: filer %s not found when listing exports", filer)
	}
	return result, nil
}

func (a *AvereVfxt) CreateCoreFiler(corefiler *CoreFiler) error {
	if _, err := a.AvereCommand(a.getCreateFilerCommand(corefiler)); err != nil {
		return err
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after adding core filer")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) EnsureInternalName(corefiler *CoreFiler) error {
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

func (a *AvereVfxt) AddCoreFilerCustomSettings(corefiler *CoreFiler) error {
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
		customSettingName := getCoreFilerCustomSettingName(corefiler.InternalName, v.Name)
		if _, ok := existingCustomSettings[customSettingName]; ok {
			// the custom setting already exists
			continue
		}
		if _, err := a.AvereCommand(a.getSetCoreFilerSettingCommand(corefiler, v)); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) RemoveCoreFilerCustomSettings(corefiler *CoreFiler) error {
	// ensure the internal name (mass) exists
	a.EnsureInternalName(corefiler)

	// get the custom settings associated with the mass
	existingCustomSettings, err := a.GetCoreFilerCustomSettings(corefiler.InternalName)
	if err != nil {
		return err
	}

	newSettingsSet := make(map[string]*CustomSetting)
	for _, v := range corefiler.CustomSettings {
		// fix the core filer settings by adding the mass
		customSetting := CustomSetting{}
		customSetting = *v
		customSetting.Name = getCoreFilerCustomSettingName(corefiler.InternalName, customSetting.Name)
		newSettingsSet[customSetting.Name] = &customSetting
	}

	// remove any that have changed or no longer exist
	for k, v := range existingCustomSettings {
		if _, ok := newSettingsSet[k]; ok {
			// due to the universal checkcode being different from the mass checkcode, only
			// compare name and value
			if (*v).Name == (*(newSettingsSet[k])).Name && (*v).Value == (*(newSettingsSet[k])).Value {
				// the setting still exists
				continue
			} else {
				log.Printf("[TRACE] Settings are different '%v' '%v'", *v, *(newSettingsSet[k]))
			}
		} else {
			log.Printf("[TRACE] setting does not exist '%v'", *v)
		}
		if _, err := a.AvereCommand(a.getRemoveCoreFilerSettingCommand(corefiler, v.Name)); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) DeleteCoreFiler(corefilerName string) error {
	_, err := a.AvereCommand(a.getDeleteFilerCommand(corefilerName))
	if err != nil {
		return err
	}
	for retries := 0; ; retries++ {
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
			break
		}
		log.Printf("[INFO] [%d/%d] filer %s still deleting", retries, FilerRetryCount, corefilerName)

		if retries > FilerRetryCount {
			return fmt.Errorf("Failure to delete after %d retries trying to delete filer %s", retries, corefilerName)
		}
		time.Sleep(FilerRetrySleepSeconds * time.Second)
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after deleting core filer")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
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

func (a *AvereVfxt) CreateJunction(junction *Junction) error {
	// listExports will cause the vFXT to refresh exports
	listExports := func() error {
		_, err := a.ListExports(junction.CoreFilerName)
		return err
	}
	if _, err := a.AvereCommandWithCorrection(a.getCreateJunctionCommand(junction), listExports); err != nil {
		return err
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after creating a junction")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) DeleteJunction(junctionNameSpacePath string) error {
	_, err := a.AvereCommand(a.getDeleteJunctionCommand(junctionNameSpacePath))
	if err != nil {
		return err
	}
	for retries := 0; ; retries++ {
		junctions, err := a.GetExistingJunctions()
		if err != nil {
			return err
		}

		if _, ok := junctions[junctionNameSpacePath]; !ok {
			// the junction is gone
			break
		}
		log.Printf("[INFO] [%d/%d] junction %s still deleting", retries, FilerRetryCount, junctionNameSpacePath)

		if retries > FilerRetryCount {
			return fmt.Errorf("Failure to delete after %d retries trying to delete junction %s", retries, junctionNameSpacePath)
		}
		time.Sleep(FilerRetrySleepSeconds * time.Second)
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after deleting junction")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) AvereCommandWithCorrection(cmd string, correctiveAction func() error) (string, error) {
	var result string
	for retries := 0; ; retries++ {
		stdoutBuf, stderrBuf, err := SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, cmd)
		if err == nil {
			// success
			result = stdoutBuf.String()
			break
		}
		log.Printf("[WARN] [%d/%d] SSH Command to %s failed with '%v' ", retries, AverecmdRetryCount, a.ControllerAddress, err)
		if isAverecmdNotRetryable(stdoutBuf, stderrBuf) {
			// failure not retryable
			return "", fmt.Errorf("Non retryable error applying command: '%s' '%s'", stdoutBuf.String(), stderrBuf.String())
		}
		if correctiveAction != nil {
			if err = correctiveAction(); err != nil {
				return "", err
			}
		}
		if retries > AverecmdRetryCount {
			// failure after exhausted retries
			return "", fmt.Errorf("Failure after %d retries applying command: '%s' '%s'", AverecmdRetryCount, stdoutBuf.String(), stderrBuf.String())
		}
		time.Sleep(AverecmdRetrySleepSeconds * time.Second)
	}
	return result, nil
}

func (a *AvereVfxt) AvereCommand(cmd string) (string, error) {
	return a.AvereCommandWithCorrection(cmd, nil)
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
			log.Printf("[INFO] vfxt: node count %d >= %d", currentNodeCount, newNodeCount)
			return nil
		}
		log.Printf("[INFO] vfxt: add node to cluster %d (target %d)", currentNodeCount, newNodeCount)

		// the cluster should be stable before and after the addition of the cluster node
		if err = a.EnsureClusterStable(); err != nil {
			return err
		}

		// only add a single node at a time
		err = a.Platform.AddIaasNodeToCluster(a)
		if err != nil {
			return err
		}

		// wait until the node is added
		targetNodeCount := currentNodeCount + 1
		for retries := 0; ; retries++ {
			nodeCount, err := a.GetCurrentNodeCount()
			if err != nil {
				return err
			}
			if nodeCount >= targetNodeCount {
				break
			}
			if retries > NodeChangeRetryCount {
				return fmt.Errorf("Failure to add node after %d retries trying to add node", retries)
			}
			time.Sleep(NodeChangeRetrySleepSeconds * time.Second)
		}
		log.Printf("[INFO] vfxt: ensure stable cluster")
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

		// remove the last node
		lastNode, err := a.GetLastNode()
		if err != nil {
			return err
		}

		// the cluster should be stable before and after the removal of the cluster node
		if err = a.EnsureClusterStable(); err != nil {
			return err
		}

		if err = a.removeNodeFromCluster(lastNode); err != nil {
			return err
		}

		// wait until the node is removed
		targetNodeCount := currentNodeCount - 1
		for retries := 0; ; retries++ {
			nodeCount, err := a.GetCurrentNodeCount()
			if err != nil {
				return err
			}
			if nodeCount <= targetNodeCount {
				break
			}
			if retries > NodeChangeRetryCount {
				return fmt.Errorf("Failure to delete after %d retries trying to delete node", retries)
			}
			time.Sleep(NodeChangeRetrySleepSeconds * time.Second)
		}

		if err = a.EnsureClusterStable(); err != nil {
			return err
		}

		// only delete the IaaS Node after the cluster is stable
		if err = a.Platform.DeleteVfxtIaasNode(a, lastNode); err != nil {
			return err
		}
	}
}

// remove a new node to the cluster
func (a *AvereVfxt) removeNodeFromCluster(nodeName string) error {
	if _, err := a.AvereCommand(a.getRemoveNodeCommand(nodeName)); err != nil {
		return err
	}

	return nil
}

func (a *AvereVfxt) getListNodesJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json node.list", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveNodeCommand(node string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json node.remove %s", a.getBaseAvereCmd(), node), AverecmdLogFile)
}

func (a *AvereVfxt) getNodeJsonCommand(node string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json node.get %s", a.getBaseAvereCmd(), node), AverecmdLogFile)
}

func (a *AvereVfxt) getClusterListActivitiesJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json cluster.listActivities", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getGetActiveAlertsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json alert.getActive", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getListCoreFilersJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json corefiler.list", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getListCoreFilerExportsJsonCommand(filer string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json corefiler.listExports %s", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getFilerJsonCommand(filer string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json corefiler.get %s", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateFilerCommand(coreFiler *CoreFiler) string {
	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.create %s %s true \"{'filerNetwork':'cluster','filerClass':'Other','cachePolicy':'%s',}\"", a.getBaseAvereCmd(), coreFiler.Name, coreFiler.FqdnOrPrimaryIp, coreFiler.CachePolicy), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteFilerCommand(filer string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.remove %s", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getVServerClientIPHomeJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json vserver.listClientIPHomes %s", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getListJunctionsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json vserver.listJunctions %s", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateJunctionCommand(junction *Junction) string {
	return WrapCommandForLogging(fmt.Sprintf("%s vserver.addJunction %s %s %s %s \"{'sharesubdir':'','inheritPolicy':'yes','sharename':'','access':'posix','createSubdirs':'yes','subdir':'','policy':''}\"", a.getBaseAvereCmd(), VServerName, junction.NameSpacePath, junction.CoreFilerName, junction.CoreFilerExport), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteJunctionCommand(junctionNameSpacePath string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s vserver.removeJunction %s %s", a.getBaseAvereCmd(), VServerName, junctionNameSpacePath), AverecmdLogFile)
}

func (a *AvereVfxt) getListCustomSettingsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json support.listCustomSettings", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSetCustomSettingCommand(customSetting string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.setCustomSetting %s", a.getBaseAvereCmd(), customSetting), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveCustomSettingCommand(customSetting string) string {
	firstArgument := getCustomSettingName(customSetting)
	return WrapCommandForLogging(fmt.Sprintf("%s support.removeCustomSetting %s", a.getBaseAvereCmd(), firstArgument), AverecmdLogFile)
}

func (a *AvereVfxt) getSetVServerSettingCommand(customSetting string) string {
	vServerCustomSetting := getVServerCustomSettingName(customSetting)
	return a.getSetCustomSettingCommand(vServerCustomSetting)
}

func (a *AvereVfxt) getRemoveVServerSettingCommand(customSetting string) string {
	vServerCustomSetting := getVServerCustomSettingName(customSetting)
	return a.getRemoveCustomSettingCommand(vServerCustomSetting)
}

func (a *AvereVfxt) getSetCoreFilerSettingCommand(corefiler *CoreFiler, customSetting *CustomSetting) string {
	coreFilerCustomSetting := getCoreFilerCustomSettingName(corefiler.InternalName, customSetting.GetCustomSettingCommand())
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
		for i := 2; i < len(parts); i++ {
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

func (a *AvereVfxt) getBaseAvereCmd() string {
	return fmt.Sprintf("averecmd --server %s --no-check-certificate --user %s --password '%s'", a.ManagementIP, AvereAdminUsername, a.AvereAdminPassword)
}

func isAverecmdNotRetryable(stdoutBuf bytes.Buffer, stderrBuf bytes.Buffer) bool {
	if len(GetErrorMatches(stdoutBuf, stderrBuf, matchWrongCheckCode)) > 0 {
		return true
	}
	if len(GetErrorMatches(stdoutBuf, stderrBuf, matchWrongNumberOfArgs)) > 0 {
		return true
	}
	if len(GetErrorMatches(stdoutBuf, stderrBuf, matchLoginFailed)) > 0 {
		return true
	}
	if len(GetErrorMatches(stdoutBuf, stderrBuf, matchMethodNotSupported)) > 0 {
		return true
	}
	if len(GetErrorMatches(stdoutBuf, stderrBuf, matchMustRemoveRelatedJunction)) > 0 {
		return true
	}
	if len(GetErrorMatches(stdoutBuf, stderrBuf, matchCannotFindMass)) > 0 {
		return true
	}
	if len(GetErrorMatches(stdoutBuf, stderrBuf, matchJunctionNotFound)) > 0 {
		return true
	}
	return false
}
