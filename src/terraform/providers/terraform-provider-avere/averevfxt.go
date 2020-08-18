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
	"strconv"
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

// parse numbers from mass
var matchNumbersInMass = regexp.MustCompile(`[^0-9]+`)

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
	sshPort int,
	runLocal bool,
	allowNonAscii bool,
	platform IaasPlatform,
	avereVfxtName string,
	avereAdminPassword string,
	sshKeyData string,
	enableSupportUploads bool,
	nodeCount int,
	nodeSize string,
	nodeCacheSize int,
	firstIPAddress string,
	lastIPAddress string,
	ntpServers string,
	timezone string,
	dnsServer string,
	dnsDomain string,
	dnsSearch string,
	proxyUri string,
	clusterProxyUri string,
	imageId string,
	managementIP string,
	vServerIPAddresses *[]string,
	nodeNames *[]string) *AvereVfxt {
	return &AvereVfxt{
		ControllerAddress:    controllerAddress,
		ControllerUsename:    controllerUsername,
		SshAuthMethod:        sshAuthMethod,
		SshPort:              sshPort,
		RunLocal:             runLocal,
		AllowNonAscii:        allowNonAscii,
		Platform:             platform,
		AvereVfxtName:        avereVfxtName,
		AvereAdminPassword:   avereAdminPassword,
		AvereSshKeyData:      sshKeyData,
		EnableSupportUploads: enableSupportUploads,
		NodeCount:            nodeCount,
		NodeSize:             nodeSize,
		NodeCacheSize:        nodeCacheSize,
		FirstIPAddress:       firstIPAddress,
		LastIPAddress:        lastIPAddress,
		NtpServers:           ntpServers,
		Timezone:             timezone,
		DnsServer:            dnsServer,
		DnsDomain:            dnsDomain,
		DnsSearch:            dnsSearch,
		ProxyUri:             proxyUri,
		ClusterProxyUri:      clusterProxyUri,
		ImageId:              imageId,
		ManagementIP:         managementIP,
		VServerIPAddresses:   vServerIPAddresses,
		NodeNames:            nodeNames,
		rePasswordReplace:    regexp.MustCompile(`-password [^ ]*`),
	}
}

func (a *AvereVfxt) RunCommand(cmd string) (bytes.Buffer, bytes.Buffer, error) {
	scrubbedCmd := a.rePasswordReplace.ReplaceAllLiteralString(cmd, "***")
	if !a.AllowNonAscii {
		if err := ValidateOnlyAscii(cmd, scrubbedCmd); err != nil {
			var stdoutBuf, stderrBuf bytes.Buffer
			return stdoutBuf, stderrBuf, err
		}
	}
	if a.RunLocal {
		return BashCommand(cmd)
	} else {
		return SSHCommand(a.ControllerAddress, a.ControllerUsename, a.SshAuthMethod, cmd, a.SshPort)
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

func (a *AvereVfxt) GetNodePrimaryIPs() ([]string, error) {
	nodeMap, err := a.GetExistingNodes()
	if err != nil {
		return nil, err
	}

	var results []string
	for _, v := range nodeMap {
		if val, ok := v.PrimaryClusterIP[PrimaryClusterIPKey]; ok {
			results = append(results, val)
		} else {
			// this is not essential data, so just print an error
			log.Printf("[ERROR] primary IP missing for node %s", v.Name)
			//return nil, fmt.Errorf("primary IP missing for node %s", v.Name)
		}
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
	for retries := 0; ; retries++ {
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
		if len(results) > 0 {
			return results, nil
		}
		if retries > VServerRetryCount {
			return nil, fmt.Errorf("Failure to get VServer IP Addresses after %d retries", retries)
		}
		time.Sleep(VServerRetrySleepSeconds * time.Second)
	}
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

func (a *AvereVfxt) GetCluster() (Cluster, error) {
	var result Cluster
	clusterJson, err := a.AvereCommand(a.getClusterGetJsonCommand())
	if err != nil {
		return result, err
	}
	if err := json.Unmarshal([]byte(clusterJson), &result); err != nil {
		return result, err
	}
	return result, nil
}

func (a *AvereVfxt) UpdateCluster() error {
	cluster, err := a.GetCluster()
	if err != nil {
		return err
	}
	_, err = a.AvereCommand(a.getClusterModifyCommand(cluster))
	return err
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
						log.Printf("[WARN] vfxt: cluster still has running activity %v", activity)
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

func (a *AvereVfxt) SetNtpServers(ntpServers string) error {
	_, err := a.AvereCommand(a.getSetNtpServersCommand(ntpServers))
	return err
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
	coreFilersJson, err := a.AvereCommand(a.getListFilersJsonCommand())
	if err != nil {
		return nil, err
	}
	var results []string
	if err := json.Unmarshal([]byte(coreFilersJson), &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) GetGenericFilers() (map[string]*CoreFilerGeneric, error) {
	coreFilersVerboseJson, err := a.AvereCommand(a.getListCoreFilersVerboseJsonCommand())
	if err != nil {
		return nil, err
	}
	var results map[string]*CoreFilerGeneric
	if err := json.Unmarshal([]byte(coreFilersVerboseJson), &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) GetGenericFilerMappingList() ([]string, error) {
	genericFilers, err := a.GetGenericFilers()
	if err != nil {
		return nil, err
	}
	result := make([]string, 0, len(genericFilers))
	for _, v := range genericFilers {
		result = append(result, fmt.Sprintf("%s:%s", v.InternalName, v.Name))
	}
	sort.Strings(result)
	return result, nil
}

func (a *AvereVfxt) GetFilerCustomSettings(filerInternalName string) (map[string]*CustomSetting, error) {
	customSettings, err := a.GetCustomSettings()
	if err != nil {
		return nil, err
	}
	results := make(map[string]*CustomSetting, 0)
	prefix := fmt.Sprintf("%s.", filerInternalName)
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

func (a *AvereVfxt) GetExistingFilers() (map[string]*CoreFiler, map[string]*AzureStorageFiler, error) {
	coreFilers, err := a.GetGenericFilers()
	if err != nil {
		return nil, nil, err
	}
	resultsCoreFiler := make(map[string]*CoreFiler)
	resultsAzureStorageFiler := make(map[string]*AzureStorageFiler)
	for filername, filer := range coreFilers {
		switch filer.FilerClass {
		case FilerClassAvereCloud:
			resultsAzureStorageFiler[filername] = filer.CreateAzureStorageFiler()
		default:
			resultsCoreFiler[filername] = filer.CreateCoreFiler()
		}
	}
	return resultsCoreFiler, resultsAzureStorageFiler, nil
}

func (a *AvereVfxt) GetGenericFiler(filer string) (*CoreFilerGeneric, error) {
	coreFilerJson, err := a.AvereCommand(a.getFilerJsonCommand(filer))
	if err != nil {
		return nil, err
	}
	var result map[string]CoreFilerGeneric
	if err := json.Unmarshal([]byte(coreFilerJson), &result); err != nil {
		return nil, err
	}
	coreFilerGeneric := result[filer]
	return &coreFilerGeneric, nil
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

func (a *AvereVfxt) EnsureCachePolicyExists(cachePolicy string, cacheMode string, checkAttributes string, writeBackDelay int) error {
	// list the cache policies
	cachePoliciesJson, err := a.AvereCommand(a.getListCachePoliciesJsonCommand())
	if err != nil {
		return err
	}
	type CachePolicy struct {
		Name string `json:"name"`
	}
	var results []CachePolicy
	if err := json.Unmarshal([]byte(cachePoliciesJson), &results); err != nil {
		return err
	}
	for _, c := range results {
		if c.Name == cachePolicy {
			// cache policy found
			return nil
		}
	}

	// if not exists, create the new policy
	if _, err := a.AvereCommand(a.getCreateCachePolicyCommand(cachePolicy, cacheMode, checkAttributes, writeBackDelay)); err != nil {
		return err
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after creating cache policy")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) ListNonAdminUsers() (map[string]*User, error) {
	usersJson, err := a.AvereCommand(a.getGetAdminListUsersJsonCommand())
	if err != nil {
		return nil, err
	}
	var users []User
	if err := json.Unmarshal([]byte(usersJson), &users); err != nil {
		return nil, err
	}
	results := make(map[string]*User)
	for _, user := range users {
		// only add the non-admin users
		if user.Name != AdminUserName {
			// add to a new user to get a valid ptr, otherwise the range changes the pointer value
			// and corrupts the results
			addUser := user
			results[addUser.Name] = &addUser
		}
	}
	return results, nil
}

func (a *AvereVfxt) AddUser(user *User) error {
	_, err := a.AvereCommand(a.getGetAdminAddUserJsonCommand(user.Name, user.Password, user.Permission))
	return err
}

func (a *AvereVfxt) RemoveUser(user *User) error {
	_, err := a.AvereCommand(a.getGetAdminRemoveUserJsonCommand(user.Name))
	return err
}

func (a *AvereVfxt) EnsureCachePolicy(corefiler *CoreFiler) error {
	switch corefiler.CachePolicy {
	case CachePolicyClientsBypass:
		return nil
	case CachePolicyReadCaching:
		return nil
	case CachePolicyReadWriteCaching:
		return nil
	case CachePolicyFullCaching:
		return nil
	case CachePolicyTransitioningClients:
		return nil
	case CachePolicyIsolatedCloudWorkstation:
		return a.EnsureCachePolicyExists(CachePolicyIsolatedCloudWorkstation, CacheModeReadWrite, CachePolicyIsolatedCloudWorkstationCheckAttributes, WriteBackDelayDefault)
	case CachePolicyCollaboratingCloudWorkstation:
		return a.EnsureCachePolicyExists(CachePolicyCollaboratingCloudWorkstation, CacheModeReadWrite, CachePolicyCollaboratingCloudWorkstationCheckAttributes, WriteBackDelayDefault)
	case CachePolicyReadOnlyHighVerificationTime:
		return a.EnsureCachePolicyExists(CachePolicyReadOnlyHighVerificationTime, CacheModeReadOnly, CachePolicyReadOnlyHighVerificationTimeCheckAttributes, 0)
	default:
		return fmt.Errorf("Error: core filer '%s' specifies unknown cache policy '%s'", corefiler.Name, corefiler.CachePolicy)
	}
}

// Create an NFS filer
func (a *AvereVfxt) CreateCoreFiler(corefiler *CoreFiler) error {
	if err := a.EnsureCachePolicy(corefiler); err != nil {
		return err
	}

	if _, err := a.AvereCommand(a.getCreateCoreFilerCommand(corefiler)); err != nil {
		return err
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after adding core filer")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

// Create storage filer
func (a *AvereVfxt) CreateAzureStorageFiler(azureStorageFiler *AzureStorageFiler) error {
	credentials, err := a.AvereCommand(a.getListCredentialsCommand())
	if err != nil {
		return err
	}
	type Credentials struct {
		Name string `json:"name"`
	}
	var resultsRaw []Credentials
	if err := json.Unmarshal([]byte(credentials), &resultsRaw); err != nil {
		return err
	}
	credentialsFound := false
	for _, credential := range resultsRaw {
		if credential.Name == azureStorageFiler.GetCloudFilerName() {
			credentialsFound = true
			break
		}
	}
	if !credentialsFound {
		createCredentialsCommand, err := a.getCreateAzureStorageCredentialsCommand(azureStorageFiler)
		if err != nil {
			return err
		}
		if _, err := a.AvereCommand(createCredentialsCommand); err != nil {
			return err
		}
	}
	// ensure the filer has a container
	if err = azureStorageFiler.PrepareForFilerCreation(a); err != nil {
		return err
	}
	// create the storage core filer
	createAzureStorageFilerCommand, err := a.getCreateAzureStorageFilerCommand(azureStorageFiler)
	if err != nil {
		return err
	}
	if _, err := a.AvereCommand(createAzureStorageFilerCommand); err != nil {
		return err
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after adding storage filer")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) GetInternalName(filerName string) (string, error) {
	// get the internal name
	newfiler, err := a.GetGenericFiler(filerName)
	if err != nil {
		return "", err
	}
	return newfiler.InternalName, nil
}

func (a *AvereVfxt) AddFilerCustomSettings(corefilerName string, customSettings []*CustomSetting) error {
	if len(customSettings) == 0 {
		// no custom settings to add
		return nil
	}

	internalName, err := a.GetInternalName(corefilerName)
	if err != nil {
		return err
	}

	// get the mass custom settings
	existingCustomSettings, err := a.GetFilerCustomSettings(internalName)
	if err != nil {
		return err
	}

	// add the new settings
	for _, v := range customSettings {
		customSettingName := getFilerCustomSettingName(internalName, v.Name)
		if _, ok := existingCustomSettings[customSettingName]; ok {
			// the custom setting already exists
			continue
		}
		if _, err := a.AvereCommand(a.getSetFilerSettingCommand(internalName, v)); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) SetFixedQuotaPercent(corefilerName string, percent int) error {
	internalName, err := a.GetInternalName(corefilerName)
	if err != nil {
		return err
	}
	massIndex := getMassIndex(internalName)
	setFixedQuotaPercentCustomSetting := fmt.Sprintf("cpolicyActive%d.fixedQuota RU %d", massIndex, percent)
	if err := a.CreateCustomSetting(setFixedQuotaPercentCustomSetting); err != nil {
		return fmt.Errorf("ERROR: failed to set fixed quota percent '%s': %s", QuotaCacheMoveMax, err)
	}
	return nil
}

func (a *AvereVfxt) RemoveFixedQuotaPercent(corefilerName string, percent int) error {
	internalName, err := a.GetInternalName(corefilerName)
	if err != nil {
		return err
	}
	massIndex := getMassIndex(internalName)
	setFixedQuotaPercentCustomSetting := fmt.Sprintf("cpolicyActive%d.fixedQuota RU %d", massIndex, percent)
	if err := a.RemoveCustomSetting(setFixedQuotaPercentCustomSetting); err != nil {
		return fmt.Errorf("ERROR: failed to remove fixed quota percent '%s': %s", QuotaCacheMoveMax, err)
	}
	return nil
}

func (a *AvereVfxt) RemoveFilerCustomSettings(corefilerName string, customSettings []*CustomSetting) error {
	internalName, err := a.GetInternalName(corefilerName)
	if err != nil {
		return err
	}

	// get the custom settings associated with the mass
	existingCustomSettings, err := a.GetFilerCustomSettings(internalName)
	if err != nil {
		return err
	}

	newSettingsSet := make(map[string]*CustomSetting)
	for _, v := range customSettings {
		// fix the core filer settings by adding the mass
		customSetting := CustomSetting{}
		customSetting = *v
		customSetting.Name = getFilerCustomSettingName(internalName, customSetting.Name)
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
		if _, err := a.AvereCommand(a.getRemoveFilerSettingCommand(v.Name)); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) DeleteFiler(corefilerName string) error {
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

func (a *AvereVfxt) DeleteAzureStorageCredentials(azureStorageFiler *AzureStorageFiler) error {
	_, err := a.AvereCommand(a.getDeleteAzureStorageCredentialsCommand(azureStorageFiler))
	if err != nil {
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

func (a *AvereVfxt) CreateVServer() error {
	if len(a.FirstIPAddress) == 0 || len(a.LastIPAddress) == 0 {
		// no first ip or last ip address.  This means the vServer would have been automatically created, just return.
		return nil
	}
	if _, err := a.AvereCommand(a.getVServerCreateCommand()); err != nil {
		return err
	}
	log.Printf("[INFO] vfxt: ensure stable cluster after creating the vServer")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
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

func (a *AvereVfxt) ModifySupportUploads() error {
	if a.EnableSupportUploads {
		if _, err := a.AvereCommand(a.getSupportAcceptTermsCommand()); err != nil {
			return err
		}
		if _, err := a.AvereCommand(a.getSupportSupportTestUploadCommand()); err != nil {
			return err
		}
	}
	if _, err := a.AvereCommand(a.getSupportModifyCustomerUploadInfoCommand()); err != nil {
		return err
	}
	if _, err := a.AvereCommand(a.getSupportSecureProactiveSupportCommand()); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) AvereCommandWithCorrection(cmd string, correctiveAction func() error) (string, error) {
	var result string
	for retries := 0; ; retries++ {
		stdoutBuf, stderrBuf, err := a.RunCommand(cmd)
		if err == nil {
			// success
			result = stdoutBuf.String()
			break
		}
		log.Printf("[WARN] [%d/%d] command to %s failed with '%v' ", retries, AverecmdRetryCount, a.ControllerAddress, err)
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
	return WrapCommandForLogging(fmt.Sprintf("%s --json node.remove %s false", a.getBaseAvereCmd(), node), AverecmdLogFile)
}

func (a *AvereVfxt) getNodeJsonCommand(node string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json node.get %s", a.getBaseAvereCmd(), node), AverecmdLogFile)
}

func (a *AvereVfxt) getClusterListActivitiesJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json cluster.listActivities", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getClusterGetJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json cluster.get", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getClusterModifyCommand(cluster Cluster) string {
	dnsServer := cluster.DnsServer
	if len(a.DnsServer) > 0 {
		dnsServer = a.DnsServer
	}
	dnsDomain := cluster.DnsDomain
	if len(a.DnsDomain) > 0 {
		dnsDomain = a.DnsDomain
	}
	dnsSearch := cluster.DnsSearch
	if len(a.DnsSearch) > 0 {
		dnsSearch = a.DnsSearch
	}
	return WrapCommandForLogging(fmt.Sprintf("%s cluster.modify \"{'timezone':'%s','DNSserver':'%s','DNSdomain':'%s','DNSsearch':'%s','mgmtIP':{'IP': '%s','netmask':'%s','vlan':'%s'}}\"", a.getBaseAvereCmd(), a.Timezone, dnsServer, dnsDomain, dnsSearch, cluster.MgmtIP.IP, cluster.MgmtIP.Netmask, cluster.InternetVlan), AverecmdLogFile)
}

func (a *AvereVfxt) getSetNtpServersCommand(ntpServers string) string {
	ntp_max_size := 3
	ntpPartialSlice := strings.Split(ntpServers, " ")
	var ntpFullSlice []string
	if len(ntpPartialSlice) >= ntp_max_size {
		ntpFullSlice = ntpPartialSlice
	} else {
		ntpFullSlice = make([]string, ntp_max_size)
		for i, v := range ntpPartialSlice {
			ntpFullSlice[i] = v
		}
	}

	return WrapCommandForLogging(fmt.Sprintf("%s cluster.modifyNTP \"%s\" \"%s\" \"%s\"", a.getBaseAvereCmd(), ntpFullSlice[0], ntpFullSlice[1], ntpFullSlice[2]), AverecmdLogFile)
}

func (a *AvereVfxt) getGetActiveAlertsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json alert.getActive", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getGetAdminListUsersJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json admin.listUsers", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getGetAdminAddUserJsonCommand(name string, password string, permission string) string {
	nonSecretAddUserBase := fmt.Sprintf("%s --json admin.addUser '%s' '%s'", a.getBaseAvereCmd(), name, permission)
	return WrapCommandForLoggingSecretInput(nonSecretAddUserBase, fmt.Sprintf("%s '%s'", nonSecretAddUserBase, password), AverecmdLogFile)
}

func (a *AvereVfxt) getGetAdminRemoveUserJsonCommand(name string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json admin.removeUser '%s'", a.getBaseAvereCmd(), name), AverecmdLogFile)
}

func (a *AvereVfxt) getUnwrappedFilersJsonCommand() string {
	return fmt.Sprintf("%s --json corefiler.list", a.getBaseAvereCmd())
}

func (a *AvereVfxt) getListFilersJsonCommand() string {
	return WrapCommandForLogging(a.getUnwrappedFilersJsonCommand(), AverecmdLogFile)
}

func (a *AvereVfxt) getListCoreFilersVerboseJsonCommand() string {
	filerArray := fmt.Sprintf("$(%s)", a.getUnwrappedFilersJsonCommand())
	return a.getFilerJsonCommand(filerArray)
}

func (a *AvereVfxt) getListCoreFilerExportsJsonCommand(filer string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json corefiler.listExports \"%s\"", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getFilerJsonCommand(filer string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json corefiler.get \"%s\"", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateCoreFilerCommand(coreFiler *CoreFiler) string {
	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.create \"%s\" \"%s\" true \"{'filerNetwork':'cluster','filerClass':'Other','cachePolicy':'%s',}\"", a.getBaseAvereCmd(), coreFiler.Name, coreFiler.FqdnOrPrimaryIp, coreFiler.CachePolicy), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateAzureStorageFilerCommand(azureStorageFiler *AzureStorageFiler) (string, error) {
	// get the value for the "bucketContents" field
	bucketContents, err := azureStorageFiler.GetBucketContents(a)
	if err != nil {
		return "", err
	}
	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.createCloudFiler \"%s\" \"{'cryptoMode':'DISABLED','maxCallsBeforeResetHTTPS':'9999','bucketContents':'%s','connectionFailoverMode':'skipBad','force':'false','connectionMode':'2','compressMode':'DISABLED','serverName':'%s.blob.core.windows.net','filerNetwork':'cluster','bucket':'%s/%s','sslVerifyMode':'DISABLED','sslMethod':'autonegotiate','cachePolicyName':'Full Caching','cloudCredential':'%s','https':'yes','nearline':'no','cloudType':'azure','type':'cloud','port': '443'}\"", a.getBaseAvereCmd(), azureStorageFiler.GetCloudFilerName(), bucketContents, azureStorageFiler.AccountName, azureStorageFiler.AccountName, azureStorageFiler.Container, azureStorageFiler.GetCloudFilerName()), AverecmdLogFile), nil
}

func (a *AvereVfxt) getDeleteFilerCommand(filer string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.remove \"%s\"", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getListCredentialsCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json corefiler.listCredentials", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateAzureStorageCredentialsCommand(azureStorageFiler *AzureStorageFiler) (string, error) {
	key, err := GetKey(a, azureStorageFiler.AccountName)
	if err != nil {
		return "", err
	}
	subscriptionId, err := GetSubscriptionId(a)
	if err != nil {
		return "", err
	}

	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.createCredential \"%s\" azure-storage \"{'note':'Automatically created from Terraform','storageKey':'BASE64:%s','tenant':'%s','subscription':'%s',}\"", a.getBaseAvereCmd(), azureStorageFiler.GetCloudFilerName(), key, azureStorageFiler.AccountName, subscriptionId), AverecmdLogFile), nil
}

func (a *AvereVfxt) getDeleteAzureStorageCredentialsCommand(azureStorageFiler *AzureStorageFiler) string {
	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.removeCredential \"%s\"", a.getBaseAvereCmd(), azureStorageFiler.GetCloudFilerName()), AverecmdLogFile)
}

func (a *AvereVfxt) getVServerClientIPHomeJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json vserver.listClientIPHomes %s", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getListCachePoliciesJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json cachePolicy.list", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateCachePolicyCommand(cachePolicy string, cacheMode string, checkAttributes string, writeBackDelay int) string {
	return WrapCommandForLogging(fmt.Sprintf("%s cachePolicy.create \"%s\" \"%s\" %d \"%s\" False", a.getBaseAvereCmd(), cachePolicy, cacheMode, writeBackDelay, checkAttributes), AverecmdLogFile)
}

func (a *AvereVfxt) getVServerCreateCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json vserver.create \"%s\" \"{'firstIP':'%s','netmask':'255.255.255.255','lastIP':'%s'}\"", a.getBaseAvereCmd(), VServerName, a.FirstIPAddress, a.LastIPAddress), AverecmdLogFile)
}

func (a *AvereVfxt) getListJunctionsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json vserver.listJunctions \"%s\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateJunctionCommand(junction *Junction) string {
	return WrapCommandForLogging(fmt.Sprintf("%s vserver.addJunction \"%s\" \"%s\" \"%s\" \"%s\" \"{'sharesubdir':'','inheritPolicy':'yes','sharename':'','access':'posix','createSubdirs':'yes','subdir':'%s','policy':'','permissions':'%s'}\"", a.getBaseAvereCmd(), VServerName, junction.NameSpacePath, junction.CoreFilerName, junction.CoreFilerExport, junction.ExportSubdirectory, junction.SharePermissions), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteJunctionCommand(junctionNameSpacePath string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s vserver.removeJunction \"%s\" \"%s\"", a.getBaseAvereCmd(), VServerName, junctionNameSpacePath), AverecmdLogFile)
}

func (a *AvereVfxt) getListCustomSettingsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json support.listCustomSettings", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSetCustomSettingCommand(customSetting string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.setCustomSetting %s \"Automatically created from Terraform\"", a.getBaseAvereCmd(), customSetting), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveCustomSettingCommand(customSetting string) string {
	firstArgument := getCustomSettingName(customSetting)
	return WrapCommandForLogging(fmt.Sprintf("%s support.removeCustomSetting %s", a.getBaseAvereCmd(), firstArgument), AverecmdLogFile)
}

// This is activated by the customer accepting the privacy policy by setting enable_support_uploads.  Otherwise, none of the examples will ever set this.
func (a *AvereVfxt) getSupportAcceptTermsCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.acceptTerms yes", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSupportSupportTestUploadCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.testUpload", a.getBaseAvereCmd()), AverecmdLogFile)
}

// this updates support uploads per docs https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-enable-support
func (a *AvereVfxt) getSupportModifyCustomerUploadInfoCommand() string {
	isEnabled := "no"
	if a.EnableSupportUploads {
		isEnabled = "yes"
	}
	return WrapCommandForLogging(fmt.Sprintf("%s support.modify \"{'crashInfo':'%s','corePolicy':'overwriteOldest','statsMonitor':'%s','rollingTrace':'no','traceLevel':'0x1','memoryDebugging':'no','generalInfo':'%s','customerId':'%s'}\"", a.getBaseAvereCmd(), isEnabled, isEnabled, isEnabled, a.AvereVfxtName), AverecmdLogFile)
}

// this updates SPS (Secure Proactive Support) per docs https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-enable-support
func (a *AvereVfxt) getSupportSecureProactiveSupportCommand() string {
	isEnabled := "no"
	if a.EnableSupportUploads {
		isEnabled = "yes"
	}
	return WrapCommandForLogging(fmt.Sprintf("%s support.modify \"{'remoteCommandEnabled':'Disabled','SPSLinkInterval':'300','SPSLinkEnabled':'%s','remoteCommandExpiration':''}\"", a.getBaseAvereCmd(), isEnabled), AverecmdLogFile)
}

func (a *AvereVfxt) getSetVServerSettingCommand(customSetting string) string {
	vServerCustomSetting := getVServerCustomSettingName(customSetting)
	return a.getSetCustomSettingCommand(vServerCustomSetting)
}

func (a *AvereVfxt) getRemoveVServerSettingCommand(customSetting string) string {
	vServerCustomSetting := getVServerCustomSettingName(customSetting)
	return a.getRemoveCustomSettingCommand(vServerCustomSetting)
}

func (a *AvereVfxt) getSetFilerSettingCommand(internalName string, customSetting *CustomSetting) string {
	coreFilerCustomSetting := getFilerCustomSettingName(internalName, customSetting.GetCustomSettingCommand())
	return a.getSetCustomSettingCommand(coreFilerCustomSetting)
}

func (a *AvereVfxt) getRemoveFilerSettingCommand(customSettingName string) string {
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

func getFilerCustomSettingName(internalName string, customSetting string) string {
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

func getMassIndex(internalName string) int {
	massIndex := matchNumbersInMass.ReplaceAllString(internalName, "")
	if len(massIndex) == 0 {
		return 0
	}
	if s, err := strconv.Atoi(massIndex); err == nil {
		return s
	}
	return 0
}
