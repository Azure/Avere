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

// NewAvereVfxt creates new AvereVfxt
func NewAvereVfxt(
	controllerAddress string,
	controllerUsername string,
	sshAuthMethod ssh.AuthMethod,
	sshPort int,
	runLocal bool,
	useAvailabilityZones bool,
	allowNonAscii bool,
	platform IaasPlatform,
	tagsMap map[string]string,
	avereVfxtName string,
	avereAdminPassword string,
	sshKeyData string,
	enableSupportUploads bool,
	enableRollingTraceData bool,
	rollingTraceFlag string,
	activeSupportUpload bool,
	secureProactiveSupport string,
	nodeCount int,
	nodeSize string,
	nodeCacheSize int,
	enableNlm bool,
	firstIPAddress string,
	lastIPAddress string,
	cifsAdDomain string,
	cifsNetbiosDomainName string,
	cifsDCAddresses string,
	cifsServerName string,
	cifsUserName string,
	cifsPassword string,
	cifsFlatFilePasswdURI string,
	cifsFlatFileGroupURI string,
	cifsFlatFilePasswdB64z string,
	cifsFlatFileGroupB64z string,
	cifsRidMappingBaseInteger int,
	cifsOrganizationalUnit string,
	cifsTrustedActiveDirectoryDomains string,
	enableExtendedGroups bool,
	loginServicesLDAPServer string,
	loginServicesLDAPBasedn string,
	loginServicesLDAPBinddn string,
	loginServicesLDAPBindPassword string,
	userAssignedManagedIdentity string,
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
		ControllerAddress:                 controllerAddress,
		ControllerUsename:                 controllerUsername,
		SshAuthMethod:                     sshAuthMethod,
		SshPort:                           sshPort,
		RunLocal:                          runLocal,
		UseAvailabilityZones:              useAvailabilityZones,
		AllowNonAscii:                     allowNonAscii,
		Platform:                          platform,
		TagsMap:                           tagsMap,
		AvereVfxtName:                     avereVfxtName,
		AvereAdminPassword:                avereAdminPassword,
		AvereSshKeyData:                   sshKeyData,
		EnableSupportUploads:              enableSupportUploads,
		EnableRollingTraceData:            enableRollingTraceData,
		RollingTraceFlag:                  rollingTraceFlag,
		ActiveSupportUpload:               activeSupportUpload,
		SecureProactiveSupport:            secureProactiveSupport,
		NodeCount:                         nodeCount,
		NodeSize:                          nodeSize,
		NodeCacheSize:                     nodeCacheSize,
		EnableNlm:                         enableNlm,
		FirstIPAddress:                    firstIPAddress,
		LastIPAddress:                     lastIPAddress,
		CifsAdDomain:                      cifsAdDomain,
		CifsNetbiosDomainName:             cifsNetbiosDomainName,
		CifsDCAddresses:                   cifsDCAddresses,
		CifsServerName:                    cifsServerName,
		CifsUsername:                      cifsUserName,
		CifsPassword:                      cifsPassword,
		CifsFlatFilePasswdURI:             cifsFlatFilePasswdURI,
		CifsFlatFileGroupURI:              cifsFlatFileGroupURI,
		CifsFlatFilePasswdB64z:            cifsFlatFilePasswdB64z,
		CifsFlatFileGroupB64z:             cifsFlatFileGroupB64z,
		CifsRidMappingBaseInteger:         cifsRidMappingBaseInteger,
		CifsOrganizationalUnit:            cifsOrganizationalUnit,
		CifsTrustedActiveDirectoryDomains: cifsTrustedActiveDirectoryDomains,
		EnableExtendedGroups:              enableExtendedGroups,
		LoginServicesLDAPServer:           loginServicesLDAPServer,
		LoginServicesLDAPBasedn:           loginServicesLDAPBasedn,
		LoginServicesLDAPBinddn:           loginServicesLDAPBinddn,
		LoginServicesLDAPBindPassword:     loginServicesLDAPBindPassword,
		UserAssignedManagedIdentity:       userAssignedManagedIdentity,
		NtpServers:                        ntpServers,
		Timezone:                          timezone,
		DnsServer:                         dnsServer,
		DnsDomain:                         dnsDomain,
		DnsSearch:                         dnsSearch,
		ProxyUri:                          proxyUri,
		ClusterProxyUri:                   clusterProxyUri,
		ImageId:                           imageId,
		ManagementIP:                      managementIP,
		VServerIPAddresses:                vServerIPAddresses,
		NodeNames:                         nodeNames,
		rePasswordReplace:                 regexp.MustCompile(`-password [^ ]*`),
		rePasswordReplace2:                regexp.MustCompile(`sshpass -p [^ ]*`),
	}
}

func (a *AvereVfxt) IsAlive() bool {
	managementIPAlivecmd := fmt.Sprintf("nc -zvv %s 443", a.ManagementIP)
	for retries := 1; ; retries++ {
		_, _, err := a.RunCommand(managementIPAlivecmd)
		if err == nil {
			return true
		}
		log.Printf("[WARN] [%d/%d] command '%s' to %s failed with '%v' ", retries, ClusterAliveRetryCount, managementIPAlivecmd, a.ControllerAddress, err)

		if retries > ClusterAliveRetryCount {
			// failure after exhausted retries
			break
		}
		time.Sleep(ClusterAliveRetrySleepSeconds * time.Second)
	}
	return false
}

func (a *AvereVfxt) RunCommand(cmd string) (bytes.Buffer, bytes.Buffer, error) {
	scrubbedCmd := a.rePasswordReplace.ReplaceAllLiteralString(cmd, "***")
	scrubbedCmd = a.rePasswordReplace2.ReplaceAllLiteralString(scrubbedCmd, "***")
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

func (a *AvereVfxt) ShellCommand(cmd string) (string, error) {
	var result string
	for retries := 0; ; retries++ {
		stdoutBuf, stderrBuf, err := a.RunCommand(cmd)
		// look for the error if this is a multi-call
		if err == nil {
			// success
			result = stdoutBuf.String()
			break
		}
		log.Printf("[WARN] [%d/%d] command failed with '%v' ", retries, ShellcmdRetryCount, err)

		if retries > ShellcmdRetryCount {
			// failure after exhausted retries
			return "", fmt.Errorf("Failure after %d retries applying command: '%s' '%s'", ShellcmdRetryCount, stdoutBuf.String(), stderrBuf.String())
		}
		time.Sleep(ShellcmdRetrySleepSeconds * time.Second)
	}
	return result, nil
}

func (a *AvereVfxt) AvereCommand(cmd string) (string, error) {
	return a.AvereCommandWithCorrection(cmd, nil)
}

func (a *AvereVfxt) AvereCommandWithCorrection(cmd string, correctiveAction func() error) (string, error) {
	var result string
	for retries := 0; ; retries++ {
		stdoutBuf, stderrBuf, err := a.RunCommand(cmd)
		// look for the error if this is a multi-call
		if err == nil && IsMultiCall(cmd) {
			if isMultiCallSuccess, faultStr, err2 := IsMultiCallResultSuccessful(stdoutBuf.String()); !isMultiCallSuccess {
				if err2 != nil {
					err = fmt.Errorf("BUG: multcall result parse error: %v", err2)
				} else if len(faultStr) > 0 {
					err = fmt.Errorf("multi call error: '%s'", faultStr)
				}
			}
		}
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
			// the corrective action is best effort, just log an error if one occurs
			if err = correctiveAction(); err != nil {
				log.Printf("[ERROR] error performing correctiveAction: %v", err)
			} else {
				// try the command again after a successful correction
				stdoutBuf, stderrBuf, err = a.RunCommand(cmd)
				if err == nil {
					// success
					result = stdoutBuf.String()
					break
				}
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
			return SortIPv4s(results), nil
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

func (a *AvereVfxt) BlockUntilClusterHealthy() error {
	return a.BlockUntilHealthy(true)
}

func (a *AvereVfxt) EnsureClusterStable() error {
	return a.BlockUntilHealthy(false)
}

func (a *AvereVfxt) BlockUntilHealthy(fullHealthCheck bool) error {
	for retries := 0; ; retries++ {

		healthy := true

		if healthy {
			// verify no activities, needed for operations
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
			// verify no active alerts, needed for operations
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

		if healthy && fullHealthCheck {
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

		if fullHealthCheck {
			// the following checks are useful to run before returning to customer

			if healthy && fullHealthCheck {
				// verify vserver is pingable
				result, err := a.VServerIPsPingable()
				if err != nil {
					return err
				}
				healthy = result
				if !healthy {
					log.Printf("[WARN] [%d/%d] vfxt: not all vserver IP addresses are pingable", retries, ClusterStableRetryCount)
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

func (a *AvereVfxt) CIFSSettingsExist() bool {
	return len(a.CifsAdDomain) > 0 && len(a.CifsNetbiosDomainName) > 0 && len(a.CifsDCAddresses) > 0 && len(a.CifsServerName) > 0 && len(a.CifsUsername) > 0 && len(a.CifsPassword) > 0
}

func (a *AvereVfxt) EnableCIFS() error {
	log.Printf("[INFO] [EnableCIFS")
	defer log.Printf("[INFO] EnableCIFS]")
	if a.CIFSSettingsExist() {
		if err := a.UpdateDCAddressOverrides(); err != nil {
			return fmt.Errorf("error adding the DC overrides")
		}
		if err := a.UploadFlatFiles(); err != nil {
			return fmt.Errorf("uploading flat files failed with error: %v", err)
		}
		if _, err := a.AvereCommand(a.getDirServicesEnableCIFSCommand()); err != nil {
			return fmt.Errorf("directory services enablement failed with error: %v", err)
		}

		if _, err := a.AvereCommand(a.getCIFSConfigureCommand()); err != nil {
			return fmt.Errorf("cifs configuration failed with error: %v", err)
		}

		if _, err := a.AvereCommand(a.getCIFSSetOptionsCommand()); err != nil {
			return fmt.Errorf("cifs set options failed with error: %v", err)
		}

		if _, err := a.AvereCommand(a.getCIFSEnableCommand()); err != nil {
			return fmt.Errorf("cifs enable failed with error: %v", err)
		}

		// finish with polling for users / groups, otherwise cifs doesn't work immediately
		if _, err := a.AvereCommand(a.getDirServicesPollUserGroupCommand()); err != nil {
			return fmt.Errorf("dir services polling failed with error: %v", err)
		}
	}

	return nil
}

func (a *AvereVfxt) DisableCIFS() error {
	if !a.CIFSSettingsExist() {
		// it is enough to just call disable CIFS to disable it
		if _, err := a.AvereCommand(a.getCIFSDisableCommand()); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) LoginSettingsExist() bool {
	return len(a.LoginServicesLDAPServer) > 0 && len(a.LoginServicesLDAPBasedn) > 0 && len(a.LoginServicesLDAPBinddn) > 0 && len(a.LoginServicesLDAPBindPassword) > 0
}

func (a *AvereVfxt) EnableLoginServices() error {
	if a.LoginSettingsExist() {
		log.Printf("[INFO] [EnableLoginServices")
		defer log.Printf("[INFO] EnableLoginServices]")
		if _, err := a.AvereCommand(a.getDirServicesSetLdapPasswordCommand()); err != nil {
			return fmt.Errorf("setting LDAP Password for login services command failed: %v", err)
		}
		// finish with polling for users / groups, otherwise cifs doesn't work immediately
		if _, err := a.AvereCommand(a.getDirServicesModifyCommand()); err != nil {
			return fmt.Errorf("modify dir services for login services failed with error: %v", err)
		}
	}

	return nil
}

func (a *AvereVfxt) DisableLoginServices() error {
	if !a.LoginSettingsExist() {
		log.Printf("[INFO] [DisableLoginServices")
		defer log.Printf("[INFO] DisableLoginServices]")
		if _, err := a.AvereCommand(a.getLoginSettingsDisableCommand()); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) ModifyExtendedGroups() error {
	log.Printf("[INFO] [ModifyExtendedGroups %v", a.EnableExtendedGroups)
	defer log.Printf("[INFO] ModifyExtendedGroups %v]", a.EnableExtendedGroups)
	if a.EnableExtendedGroups {
		if _, err := a.AvereCommand(a.getEnableExtendedGroupsCommand()); err != nil {
			return err
		}
	} else {
		if _, err := a.AvereCommand(a.getDisableExtendedGroupsCommand()); err != nil {
			return err
		}
	}
	return nil
}

func (a *AvereVfxt) SetNtpServers(ntpServers string) error {
	_, err := a.AvereCommand(a.getSetNtpServersCommand(ntpServers))
	return err
}

func (a *AvereVfxt) CreateCustomSetting(customSetting string, message string) error {
	_, err := a.AvereCommand(a.getSetCustomSettingCommand(customSetting, message))
	return err
}

func (a *AvereVfxt) RemoveCustomSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getRemoveCustomSettingCommand(customSetting))
	return err
}

func (a *AvereVfxt) CreateVServerSetting(customSetting string) error {
	_, err := a.AvereCommand(a.getSetVServerSettingCommand(customSetting, GetTerraformMessage(customSetting)))
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

// use the following command if we encounter "permission errors", this is modeled after the UI
func (a *AvereVfxt) EnableAPIMaintenance() error {
	if _, err := a.AvereCommand(a.getEnableAPIMaintenanceCommand()); err != nil {
		return err
	}
	return nil
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

func ValidateCachePolicy(v interface{}, _ string) (warnings []string, errors []error) {
	cachePolicy := v.(string)

	switch cachePolicy {
	case CachePolicyClientsBypass,
		CachePolicyReadCaching,
		CachePolicyReadWriteCaching,
		CachePolicyFullCaching,
		CachePolicyTransitioningClients,
		CachePolicyIsolatedCloudWorkstation,
		CachePolicyCollaboratingCloudWorkstation,
		CachePolicyReadOnlyHighVerificationTime:
		break
	default:
		if cachePolicyClientsBypassCustom, timeout := isCachePolicyClientsBypassCustom(cachePolicy); cachePolicyClientsBypassCustom {
			if timeout < 0 {
				errors = append(errors, fmt.Errorf("Error: timeout for cache policy '%s' must be greater than 0", cachePolicy))
			}
			break
		} else {
			if strings.Contains(cachePolicy, CachePolicyClientsBypass) {
				errors = append(errors, fmt.Errorf("Error: incorrect format for custom client bypass. Example format for 20s '%s%d'", CachePolicyClientsBypass, 20))
			} else {
				errors = append(errors, fmt.Errorf("Error: unknown cache policy '%s'", cachePolicy))
			}
		}
	}

	return warnings, errors
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
		if cachePolicyClientsBypassCustom, timeout := isCachePolicyClientsBypassCustom(corefiler.CachePolicy); cachePolicyClientsBypassCustom {
			return a.EnsureCachePolicyExists(corefiler.CachePolicy, CacheModeReadOnly, getCachePolicyClientsBypassCustomCheckAttributes(timeout), 0)
		} else {
			return fmt.Errorf("Error: core filer '%s' specifies unknown cache policy '%s'", corefiler.Name, corefiler.CachePolicy)
		}
	}
}

func isCachePolicyClientsBypassCustom(cachePolicy string) (bool, int) {
	timeoutStr := strings.TrimPrefix(cachePolicy, CachePolicyClientsBypass)
	if timeout, err := strconv.Atoi(timeoutStr); err == nil {
		return true, timeout
	}
	return false, 0
}

func getCachePolicyClientsBypassCustomCheckAttributes(timeout int) string {
	return fmt.Sprintf(CachePolicyClientsBypassCustomCheckAttributes, timeout)
}

func IsCachePolicyReadOnly(cachePolicy string) bool {
	switch cachePolicy {
	case CachePolicyClientsBypass:
		return true
	case CachePolicyReadCaching:
		return true
	case CachePolicyReadOnlyHighVerificationTime:
		return true
	default:
		if cachePolicyClientsBypassCustom, _ := isCachePolicyClientsBypassCustom(cachePolicy); cachePolicyClientsBypassCustom {
			return true
		} else {
			return false
		}

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

	if err := a.EnsureServerAddressCorrect(corefiler); err != nil {
		return err
	}

	log.Printf("[INFO] vfxt: ensure stable cluster after adding core filer")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) PrepareForVFXTNodeCommands() error {
	log.Printf("[INFO] [PrepareForVFXTNodeCommands")
	defer log.Printf("[INFO] PrepareForVFXTNodeCommands]")

	if _, err := a.ShellCommand(getEnsureSSHPass()); err != nil {
		return fmt.Errorf("Error installing sshpass: %v", err)
	}

	// the Avere management ip address can change from node to node, so we need to clear the known hosts files
	if _, err := a.ShellCommand(getEnsureNoKnownHosts()); err != nil {
		return fmt.Errorf("Error removing known hosts file: %v", err)
	}

	return nil
}

func (a *AvereVfxt) GetExistingDCAddressOverrides() ([]AdOverride, error) {
	log.Printf("[INFO] [GetExistingDCAddressOverrides")
	defer log.Printf("[INFO] GetExistingDCAddressOverrides]")
	dcAddressOverridesJson, err := a.AvereCommand(a.getListAdOverrideJSONCommand())
	if err != nil {
		return nil, err
	}
	var results []AdOverride
	if err := json.Unmarshal([]byte(dcAddressOverridesJson), &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) GetDCAddressOverridesToAddandDelete(adOverrides []AdOverride) ([]AdOverride, []AdOverride) {
	log.Printf("[INFO] [GetDCAddressOverridesToAddandDelete")
	defer log.Printf("[INFO] GetDCAddressOverridesToAddandDelete]")
	var overridesToAdd []AdOverride
	var overridesToDelete []AdOverride

	overrideExists := false
	for _, o := range adOverrides {
		if o.IsEqual(a.CifsNetbiosDomainName, a.CifsAdDomain, a.CifsDCAddresses) {
			overrideExists = true
		} else {
			overridesToDelete = append(overridesToDelete, o)
		}
	}
	if !overrideExists {
		o := AdOverride{
			Netbios:   a.CifsNetbiosDomainName,
			Fqdn:      a.CifsAdDomain,
			Addresses: a.CifsDCAddresses,
		}
		overridesToAdd = append(overridesToAdd, o)
	}

	return overridesToAdd, overridesToDelete
}

func (a *AvereVfxt) UpdateDCAddressOverrides() error {
	log.Printf("[INFO] [updating DC Address Overrides")
	defer log.Printf("[INFO] updating DC Address Overrides]")

	adOverrides, err := a.GetExistingDCAddressOverrides()
	if err != nil {
		return err
	}

	overridesToAdd, overridesToDelete := a.GetDCAddressOverridesToAddandDelete(adOverrides)
	if err != nil {
		return err
	}

	// delete override
	for _, o := range overridesToDelete {
		log.Printf("[INFO] removing DC Override %s, %s", o.Netbios, o.Fqdn)
		if _, err := a.AvereCommand(a.getRemoveAdOverrideCommand(o.Netbios, o.Fqdn)); err != nil {
			return err
		}
	}

	// add override
	for _, o := range overridesToAdd {
		log.Printf("[INFO] adding DC Override %s, %s, '%s'", o.Netbios, o.Fqdn, o.Addresses)
		if _, err := a.AvereCommand(a.getAddAdOverrideCommand(o.Netbios, o.Fqdn, o.Addresses)); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) IsUsingFlatFiles() bool {
	return a.CifsRidMappingBaseInteger > 0 || (len(a.CifsFlatFilePasswdB64z) > 0 && len(a.CifsFlatFileGroupB64z) > 0)
}

func (a *AvereVfxt) UploadFlatFiles() error {
	if !a.IsUsingFlatFiles() {
		return nil
	}
	log.Printf("[INFO] [uploading flat files")
	defer log.Printf("[INFO] uploading flat files]")

	// cleanup any existing flat files, this avoids failed copy or generation because of incorrect permissions
	if _, err := a.ShellCommand(a.getCleanFlatFileCommand()); err != nil {
		return fmt.Errorf("Error cleaning up flat files: %v", err)
	}

	if a.CifsRidMappingBaseInteger > 0 {
		log.Printf("[INFO] step 1 - upload rid generator")
		ridGeneratorFileB64z, err := GetRidGeneratorB64z()
		if err != nil {
			return fmt.Errorf("Error create rid generator b64z file: %s", ridGeneratorFileB64z)
		}
		if _, err := a.ShellCommand(a.getPutRidGeneratorCommand(ridGeneratorFileB64z)); err != nil {
			return fmt.Errorf("Error uploading rid generator file: %v", err)
		}

		log.Printf("[INFO] step 2 - copy rid generator to Avere and execute")
		scpCmd := a.getRidGeneratorScpCommand()
		if _, err := a.ShellCommand(scpCmd); err != nil {
			return fmt.Errorf("Error running scp command for rid generator: %v", err)
		}

		log.Printf("[INFO] step 2.1 - Execute rid generator")
		ridGeneratorCmd := a.getExecuteRidGeneratorCommand()
		if _, err := a.ShellCommand(ridGeneratorCmd); err != nil {
			return fmt.Errorf("Error running rid generator execution: %v", err)
		}
	} else {
		log.Printf("[INFO] step 1 - put flat files on controller")
		if _, err := a.ShellCommand(a.getPutPasswdFileCommand()); err != nil {
			return fmt.Errorf("Error uploading passwd file: %v", err)
		}

		if _, err := a.ShellCommand(a.getPutGroupFileCommand()); err != nil {
			return fmt.Errorf("Error uploading group file: %v", err)
		}

		log.Printf("[INFO] step 2 - copy to Avere webserver")
		scpCmd := a.getFlatFileScpCommand()
		if _, err := a.ShellCommand(scpCmd); err != nil {
			return fmt.Errorf("Error running scp command: %v", err)
		}
	}

	mountWritableCmd := a.getMakeVFXTWritableCommand()
	if _, err := a.ShellCommand(mountWritableCmd); err != nil {
		return fmt.Errorf("Error running mount writable command: %v", err)
	}
	mountReadonlyCmd := a.getMakeVFXTReadonlyCommand()
	// always mount readable
	defer func() {
		if _, err := a.ShellCommand(mountReadonlyCmd); err != nil {
			log.Printf("[ERROR] Error running mount readable command: %v", err)
		}
	}()
	copyUserCmd := a.getCopyPasswdFileCommand()
	if _, err := a.ShellCommand(copyUserCmd); err != nil {
		return fmt.Errorf("Error running copy group command: %v", err)
	}
	copyGroupCmd := a.getCopyGroupFileCommand()
	if _, err := a.ShellCommand(copyGroupCmd); err != nil {
		return fmt.Errorf("Error running copy group command: %v", err)
	}

	log.Printf("[INFO] step 3 - cleanup")
	// done in the defer command

	return nil
}

// if the fqdn is in multiple parts, run the dbutil.py command, as there
// is a bug in averecmd that only sets the first ip address
func (a *AvereVfxt) EnsureServerAddressCorrect(corefiler *CoreFiler) error {
	fqdnParts := strings.Split(corefiler.FqdnOrPrimaryIp, " ")
	if len(fqdnParts) <= 1 {
		return nil
	}
	log.Printf("[INFO] working around averecmd bug to set server addresses '%s'", corefiler.FqdnOrPrimaryIp)

	// get the mass
	internalName, err := a.GetInternalName(corefiler.Name)
	if err != nil {
		return err
	}

	dbUtilCommand := a.getSetServerAddrCommand(internalName, corefiler.FqdnOrPrimaryIp)
	if _, err := a.ShellCommand(dbUtilCommand); err != nil {
		return fmt.Errorf("Error running dbutil.py command: %v", err)
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

func (a *AvereVfxt) AddStorageFilerCustomSettings(storageFiler *AzureStorageFiler) error {
	if len(storageFiler.CustomSettings) == 0 {
		// no custom settings to add
		return nil
	}

	internalName, err := a.GetInternalName(storageFiler.GetCloudFilerName())
	if err != nil {
		return err
	}

	if err := a.AddFilerCustomSettingsList(internalName, storageFiler.CustomSettings); err != nil {
		return err
	}

	return nil
}

func (a *AvereVfxt) AddCoreFilerCustomSettings(coreFiler *CoreFiler) error {
	internalName, err := a.GetInternalName(coreFiler.Name)
	if err != nil {
		return err
	}

	// always add connection multiplier setting: this is a common bottleneck and support issue
	if err := a.AddFilerCustomerSettingAsFeature(internalName, InitializeCustomSetting(GetNFSConnectionMultiplierSetting(coreFiler.NfsConnectionMultiplier))); err != nil {
		return err
	}

	// add all custom setting features
	if coreFiler.AutoWanOptimize {
		if err := a.AddFilerCustomerSettingAsFeature(internalName, InitializeCustomSetting(AutoWanOptimizeCustomSetting)); err != nil {
			return err
		}
	}

	if len(coreFiler.CustomSettings) > 0 {
		if err := a.AddFilerCustomSettingsList(internalName, coreFiler.CustomSettings); err != nil {
			return err
		}
	}

	return nil
}

func (a *AvereVfxt) AddFilerCustomerSettingAsFeature(internalName string, customSetting *CustomSetting) error {
	if _, err := a.AvereCommand(a.getSetFilerSettingCommand(internalName, customSetting, TerraformFeatureMessage)); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) AddFilerCustomSettingsList(internalName string, customSettings []*CustomSetting) error {
	// get the mass custom settings
	existingCustomSettings, err := a.GetFilerCustomSettings(internalName)
	if err != nil {
		return err
	}

	// add the new settings
	for _, v := range customSettings {
		customSettingName := GetFilerCustomSetting(internalName, v.Name)
		if _, ok := existingCustomSettings[customSettingName]; ok {
			// the custom setting already exists
			continue
		}
		if _, err := a.AvereCommand(a.getSetFilerSettingCommand(internalName, v, v.GetTerraformMessage())); err != nil {
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
	if err := a.CreateCustomSetting(setFixedQuotaPercentCustomSetting, TerraformFeatureMessage); err != nil {
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

func (a *AvereVfxt) RemoveStorageFilerCustomSettings(storageFiler *AzureStorageFiler) error {
	return a.RemoveFilerCustomSettings(storageFiler.GetCloudFilerName(), storageFiler.CustomSettings)
}

func (a *AvereVfxt) RemoveCoreFilerCustomSettings(coreFiler *CoreFiler) error {
	allCustomSettings := make([]*CustomSetting, len(coreFiler.CustomSettings), len(coreFiler.CustomSettings)+1)
	copy(allCustomSettings, coreFiler.CustomSettings)

	// add all custom setting features
	allCustomSettings = append(allCustomSettings, InitializeCustomSetting(GetNFSConnectionMultiplierSetting(coreFiler.NfsConnectionMultiplier)))
	if coreFiler.AutoWanOptimize {
		allCustomSettings = append(allCustomSettings, InitializeCustomSetting(AutoWanOptimizeCustomSetting))
	}

	return a.RemoveFilerCustomSettings(coreFiler.Name, allCustomSettings)
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
		customSetting.SetFilerCustomSettingName(internalName)
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
	enableAPIMaintenance := func() error {
		err := a.EnableAPIMaintenance()
		return err
	}

	_, err := a.AvereCommandWithCorrection(a.getDeleteFilerCommand(corefilerName), enableAPIMaintenance)
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
	cifsShares, err := a.GetCifShares()
	if err != nil {
		return nil, err
	}
	for _, v := range jsonResults {
		// create a new object to assign v
		newJunction := Junction{}
		newJunction = v
		// assign existing rules, or an empty map
		if newJunction.PolicyName == GenerateExportPolicyName(newJunction.NameSpacePath) {
			newJunction.ExportRules, err = a.GetExportRules(newJunction.PolicyName)
			if err != nil {
				return nil, err
			}
		} else {
			newJunction.ExportRules = make(map[string]*ExportRule)
		}
		// assign existing shares, aces, and masks, or default values
		if cifsShare, ok := cifsShares[newJunction.NameSpacePath]; ok {
			newJunction.CifsShareName = cifsShare.ShareName
			newJunction.CifsCreateMask = cifsShare.CreateMask
			newJunction.CifsDirMask = cifsShare.DirMask
			shareAces, err := a.GetCifShareAces(newJunction.CifsShareName)
			if err != nil {
				return nil, err
			}
			newJunction.CifsAces = shareAces
		} else {
			// assign default values
			newJunction.CifsAces = make(map[string]*ShareAce)
			newJunction.CifsCreateMask = ""
			newJunction.CifsDirMask = ""
		}
		log.Printf("[INFO] CIFS Share %s, masks '%s' '%s' (corefiler cifs share '%s')", newJunction.CifsShareName, newJunction.CifsCreateMask, newJunction.CifsDirMask, newJunction.CoreFilerCifsShareName)
		results[newJunction.NameSpacePath] = &newJunction
	}

	return results, nil
}

func (a *AvereVfxt) GetCifShares() (map[string]*CifsShare, error) {
	results := make(map[string]*CifsShare)
	cifSharesJson, err := a.AvereCommand(a.getListCIFSSharesJSONCommand())
	if err != nil {
		return nil, err
	}
	var jsonResults []CifsShare
	if err := json.Unmarshal([]byte(cifSharesJson), &jsonResults); err != nil {
		return nil, err
	}
	for _, v := range jsonResults {
		cifsShare := CifsShare{}
		cifsShare = v
		cifsSharePtr := &cifsShare
		results[cifsSharePtr.GetNameSpacePath()] = cifsSharePtr
	}
	return results, nil
}

func (a *AvereVfxt) GetCifShareAces(sharename string) (map[string]*ShareAce, error) {
	results := make(map[string]*ShareAce)
	cifShareAclsJson, err := a.AvereCommand(a.getGetShareAclsJSONCommand(sharename))
	if err != nil {
		return nil, err
	}
	var jsonResults []ShareAce
	if err := json.Unmarshal([]byte(cifShareAclsJson), &jsonResults); err != nil {
		return nil, err
	}
	for _, v := range jsonResults {
		cifsShareAcePtr := InitializeCleanAce(&v)
		results[cifsShareAcePtr.Name] = cifsShareAcePtr
	}
	return results, nil
}

func (a *AvereVfxt) DeleteCifsShare(sharename string) error {
	log.Printf("[INFO] [DeleteCifsShare %s", sharename)
	defer log.Printf("[INFO] DeleteCifsShare %s]", sharename)
	// delete the cifs share
	// no need to touch aces as they disappear with the share, and if
	// it is recreated, we update the aces
	if _, err := a.AvereCommand(a.getRemoveCIFSShareCommand(sharename)); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) AddCifsShare(junction *Junction) error {
	log.Printf("[INFO] [AddCifsShare %s ns:%s with masks '%s' and '%s'", junction.CifsShareName, junction.NameSpacePath, junction.CifsCreateMask, junction.CifsDirMask)
	defer log.Printf("[INFO] AddCifsShare %s ns:%s]", junction.CifsShareName, junction.NameSpacePath)

	if _, err := a.AvereCommand(a.getAddCIFSShareCommand(junction.CifsShareName, junction.NameSpacePath, junction.CifsCreateMask, junction.CifsDirMask)); err != nil {
		return err
	}

	if err := a.UpdateCifsAces(junction); err != nil {
		return err
	}

	return nil
}

func (a *AvereVfxt) UpdateCifsAces(junction *Junction) error {
	log.Printf("[INFO] [UpdateCifsAces %s", junction.CifsShareName)
	defer log.Printf("[INFO] UpdateCifsAces %s]", junction.CifsShareName)

	if len(junction.CifsShareName) > 0 {
		// get the aces
		existingShareAces, err := a.GetCifShareAces(junction.CifsShareName)
		if err != nil {
			return err
		}

		shareAcesToDelete, shareAcesToCreate := GetShareAceAdjustments(existingShareAces, junction.CifsAces)
		log.Printf("[INFO] deleting %d aces, adding %d aces", len(shareAcesToDelete), len(shareAcesToCreate))
		for _, v := range shareAcesToDelete {
			if _, err := a.AvereCommand(a.getGetRemoveShareAceCommand(junction.CifsShareName, v)); err != nil {
				return err
			}
		}
		for _, v := range shareAcesToCreate {
			if _, err := a.AvereCommand(a.getGetAddShareAceCommand(junction.CifsShareName, v)); err != nil {
				return err
			}
		}
	}

	return nil
}

func (a *AvereVfxt) UpdateCifsMasks(junction *Junction) error {
	log.Printf("[INFO] [UpdateCifsMasks %s with masks '%s' and '%s'", junction.CifsShareName, junction.CifsCreateMask, junction.CifsDirMask)
	defer log.Printf("[INFO] UpdateCifsMasks %s]", junction.CifsShareName)
	// add the cifs share
	if len(junction.CifsShareName) > 0 {
		if _, err := a.AvereCommand(a.getUpdateCIFSShareCommand(junction.CifsShareName, junction.CifsCreateMask, junction.CifsDirMask)); err != nil {
			return err
		}
	}
	return nil
}

// Approach derived from Avere document "Disable NLM Locking Version 1.0", 2019-09-18
func (a *AvereVfxt) SetNlm() error {
	log.Printf("[INFO] [SetNlm(%v)", a.EnableNlm)
	defer log.Printf("[INFO] SetNlm]")

	// get the vserver
	vServerMappings, err := a.GetVServerMappings()
	if err != nil {
		return err
	}
	internalVServerName, ok := vServerMappings[VServerName]
	if !ok {
		return fmt.Errorf("ERROR: vserver '%s' is missing, and needed for disabling NLM", VServerName)
	}

	// get NLM status, if it matches exit with nil
	nlmEnabled, err := a.IsNLMEnabled(internalVServerName)
	if err != nil {
		return err
	}
	if a.EnableNlm == nlmEnabled {
		log.Printf("[INFO] nlm state '%v' is already at expected state '%v', nothing to do", nlmEnabled, a.EnableNlm)
		return nil
	}

	// cluster exec set serverNlm
	serverNlmNoProbe := DBUtilNo
	serverNlm := DBUtilYes
	if !a.EnableNlm {
		serverNlmNoProbe = DBUtilYes
		serverNlm = DBUtilNo
	}
	if _, err := a.ShellCommand(a.getSetServerNlmNoProbeCommand(internalVServerName, serverNlmNoProbe)); err != nil {
		return err
	}
	if _, err := a.ShellCommand(a.getSetServerNlm(internalVServerName, serverNlm)); err != nil {
		return err
	}

	if err := a.RestartArmada(); err != nil {
		return err
	}

	return nil
}

func (a *AvereVfxt) RestartArmada() error {
	log.Printf("[INFO] [RestartArmada(%v)", a.EnableNlm)
	defer log.Printf("[INFO] RestartArmada]")

	// get static IP
	primaryIPs, err := a.GetNodePrimaryIPs()
	if err != nil {
		return fmt.Errorf("error encountered getting nodes primary ips '%v'", err)
	}
	if len(primaryIPs) == 0 {
		return fmt.Errorf("BUG: there are no primary ip addresses")
	}
	staticIp := primaryIPs[0]

	// since we are using a non-mgmt IP clear the known hosts before and after the restart
	if err := a.PrepareForVFXTNodeCommands(); err != nil {
		return err
	}

	if _, err := a.ShellCommand(a.getRestartArmadaCommand(staticIp)); err != nil {
		return err
	}

	if err := a.PrepareForVFXTNodeCommands(); err != nil {
		return err
	}

	// wait to settle
	log.Printf("[INFO] vfxt: ensure stable cluster after restarting Armada")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) IsNLMEnabled(internalVServerName string) (bool, error) {
	enabledResult := false

	rawResult, err := a.ShellCommand(a.getServerNlmNoProbeCommand(internalVServerName))
	if err != nil {
		return enabledResult, err
	}

	// parse a result similar to vserver1.serverNlmNoProbe: yes
	parts := strings.Split(rawResult, ":")
	if len(parts) < 2 {
		return true, nil
	}
	result := strings.TrimSpace(parts[1])

	return result != DBUtilYes, nil
}

func (a *AvereVfxt) GetVServerInternalNames() ([]string, error) {
	results := make([]string, 0)

	vserverRawList, err := a.ShellCommand(a.getVServerInternalNamesCommand())
	if err != nil {
		return results, err
	}

	scanner := bufio.NewScanner(strings.NewReader(vserverRawList))
	for scanner.Scan() {
		line := scanner.Text()
		// filter out the meta data lines that begin with '_'
		if strings.HasPrefix(line, "_") {
			continue
		}
		// split a line similar to "vserver1: aa87576c-7c09-11eb-b929-000d3a8b2a07"
		parts := strings.Split(line, ":")
		// if line was empty, continue
		if len(parts) == 0 {
			continue
		}
		trimmedLine := strings.TrimSpace(parts[0])
		if len(trimmedLine) > 0 {
			results = append(results, trimmedLine)
		}
	}

	return results, nil
}

func (a *AvereVfxt) GetVServerMappings() (map[string]string, error) {
	results := make(map[string]string)

	vserverInternalNames, err := a.GetVServerInternalNames()
	if err != nil {
		return nil, err
	}

	for _, internalName := range vserverInternalNames {
		// TODO - probably need shell command
		vserverName, err := a.ShellCommand(a.getVServerNameCommand(internalName))
		if err != nil {
			return nil, fmt.Errorf("ERROR getting versver name from internal name '%s': '%v'", internalName, err)
		}
		trimVserverName := strings.TrimSpace(vserverName)
		if len(trimVserverName) == 0 {
			return nil, fmt.Errorf("ERROR getting empty vservername for internal name '%s'", internalName)
		}
		results[trimVserverName] = internalName
	}

	return results, nil
}

func (a *AvereVfxt) VServerIPsPingable() (bool, error) {
	log.Printf("[INFO] [VServerIPsPingable")
	defer log.Printf("[INFO] VServerIPsPingable]")

	var contiguousIPAddressList [][]string
	if len(a.FirstIPAddress) == 0 {
		currentVServerIPAddresses, err := a.GetVServerIPAddresses()
		if err != nil {
			return false, fmt.Errorf("error encountered while getting vserver addresses '%v'", err)
		}
		vServerIPAddressCount := len(currentVServerIPAddresses)
		if vServerIPAddressCount == 0 {
			return false, fmt.Errorf("error: no vserver addresses exist")
		}
		contiguousIPAddressList = GetContiguousIPSlices(currentVServerIPAddresses)
	} else {
		firstVServerIPAddress := a.FirstIPAddress
		lastVServerIPAddress := a.LastIPAddress
		contiguousIPAddressList = make([][]string, 0)
		contiguousIPAddressList = append(contiguousIPAddressList, []string{firstVServerIPAddress, lastVServerIPAddress})
	}

	success := true
	for _, ipPair := range contiguousIPAddressList {
		firstQuartet, err := GetIPAddressLastQuartet(ipPair[0])
		if err != nil {
			return false, err
		}
		lastQuartet, err := GetIPAddressLastQuartet(ipPair[1])
		if err != nil {
			return false, err
		}
		addressPrefix, err := GetIPAddress3QuartetPrefix(ipPair[0])
		if err != nil {
			return false, err
		}

		result, err := a.ShellCommand(GetPingIPAddressesCommand(firstQuartet, lastQuartet, addressPrefix))
		pingableResult := !strings.Contains(result, "timed out")
		log.Printf("[INFO] VServerIP address %s%d-%d pingable result: %v", addressPrefix, firstQuartet, lastQuartet, pingableResult)
		success = success && pingableResult
	}
	return success, nil
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

func (a *AvereVfxt) CreateExportPolicy(policyName string) error {
	log.Printf("[INFO] [CreateExportPolicy %s", policyName)
	defer log.Printf("[INFO] CreateExportPolicy %s]", policyName)
	deleteExport := func() error {
		err := a.DeleteExportPolicy(policyName)
		return err
	}
	if _, err := a.AvereCommandWithCorrection(a.getCreateExportPolicyCommand(policyName), deleteExport); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) DeleteExportPolicy(policyName string) error {
	log.Printf("[INFO] [DeleteExportPolicy %s", policyName)
	defer log.Printf("[INFO] DeleteExportPolicy %s]", policyName)
	if _, err := a.AvereCommand(a.getDeleteExportPolicyCommand(policyName)); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) AddExportRules(policyName string, exportRules map[string]*ExportRule) error {
	log.Printf("[INFO] [AddExportRules %s", policyName)
	defer log.Printf("[INFO] AddExportRules %s]", policyName)
	for _, v := range exportRules {
		if _, err := a.AvereCommand(a.getCreateExportRuleCommand(policyName, v)); err != nil {
			return err
		}
	}
	return nil
}

func (a *AvereVfxt) DeleteExportRules(policyName string, exportRules map[string]*ExportRule) error {
	log.Printf("[INFO] [DeleteExportRules %s", policyName)
	defer log.Printf("[INFO] DeleteExportRules %s]", policyName)

	if policyName == DefaultExportPolicyName {
		log.Printf("[INFO] default policy, nothing to do")
		return nil
	}

	for _, v := range exportRules {
		if len(v.Id) == 0 {
			return fmt.Errorf("BUG: the export rule '%s' for policy '%s' cannot have an empty id, this should have come from function GetExportRules", v.Filter, policyName)
		}
		if _, err := a.AvereCommand(a.getDeleteExportRuleCommand(v.Id)); err != nil {
			return err
		}
	}
	return nil
}

func (a *AvereVfxt) UpdateExportRules(junction *Junction) error {
	log.Printf("[INFO] [UpdateExportRules %s", junction.NameSpacePath)
	defer log.Printf("[INFO] UpdateExportRules %s]", junction.NameSpacePath)

	// get the aces
	existingRules, err := a.GetExportRules(junction.PolicyName)
	if err != nil {
		return err
	}

	rulesToDelete, rulesToCreate := GetExportRuleAdjustments(existingRules, junction.ExportRules)
	log.Printf("[INFO] deleting %d rules, adding %d rules", len(rulesToDelete), len(rulesToCreate))
	if err := a.DeleteExportRules(junction.PolicyName, rulesToDelete); err != nil {
		return err
	}
	if err := a.AddExportRules(junction.PolicyName, rulesToCreate); err != nil {
		return err
	}

	return nil
}

func (a *AvereVfxt) GetExportRules(policyName string) (map[string]*ExportRule, error) {
	results := make(map[string]*ExportRule)
	exportRulesJson, err := a.AvereCommand(a.getListExportRulesJsonCommand(policyName))
	if err != nil {
		return results, err
	}
	var exportRules []ExportRule
	if err := json.Unmarshal([]byte(exportRulesJson), &exportRules); err != nil {
		return results, err
	}
	for _, e := range exportRules {
		// make a copy before assigning the exportRule, otherwise we end up with a map of all the same items
		exportRule := ExportRule{}
		exportRule = e
		results[exportRule.Filter] = &exportRule
	}
	return results, nil
}

func (a *AvereVfxt) CreateJunction(junction *Junction) error {
	log.Printf("[INFO] [CreateJunction %s", junction.NameSpacePath)
	defer log.Printf("[INFO] CreateJunction %s]", junction.NameSpacePath)
	policyName := ""
	if len(junction.ExportRules) > 0 {
		policyName = GenerateExportPolicyName(junction.NameSpacePath)
		if err := a.CreateExportPolicy(policyName); err != nil {
			return err
		}
		if err2 := a.AddExportRules(policyName, junction.ExportRules); err2 != nil {
			return err2
		}
	}
	// listExports will cause the vFXT to refresh exports
	listExports := func() error {
		_, err := a.ListExports(junction.CoreFilerName)
		return err
	}
	if _, err := a.AvereCommandWithCorrection(a.getCreateJunctionCommand(junction, policyName), listExports); err != nil {
		return err
	}
	// add the cifs share
	if len(junction.CifsShareName) > 0 {
		if err := a.AddCifsShare(junction); err != nil {
			return err
		}
	}
	return nil
}

func (a *AvereVfxt) WaitForJunctionToRemove(junctionNameSpacePath string) error {
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
	return nil
}

func (a *AvereVfxt) GetExportPolicies() (map[string]bool, error) {
	results := make(map[string]bool)
	exportPoliciesJson, err := a.AvereCommand(a.getListExportPoliciesJsonCommand())
	if err != nil {
		return results, err
	}
	var policies []string
	if err := json.Unmarshal([]byte(exportPoliciesJson), &policies); err != nil {
		return results, err
	}
	for _, p := range policies {
		results[p] = true
	}
	return results, nil
}

func (a *AvereVfxt) ExportPolicyExists(policyName string) (bool, error) {
	exportPolicyMap, err := a.GetExportPolicies()
	if err != nil {
		return false, err
	}
	_, ok := exportPolicyMap[policyName]
	return ok, nil
}

func (a *AvereVfxt) DeleteExportPolicyIfExists(junctionNameSpacePath string) error {
	policyName := GenerateExportPolicyName(junctionNameSpacePath)
	policyExists, err := a.ExportPolicyExists(policyName)
	if err != nil {
		return err
	}
	if policyExists {
		if _, err := a.AvereCommand(a.getDeleteExportPolicyCommand(policyName)); err != nil {
			return err
		}
	}
	return nil
}

func (a *AvereVfxt) DeleteJunction(junctionNameSpacePath string) error {
	log.Printf("[INFO] [DeleteJunction %s", junctionNameSpacePath)
	defer log.Printf("[INFO] DeleteJunction %s]", junctionNameSpacePath)
	if _, err := a.AvereCommand(a.getDeleteJunctionCommand(junctionNameSpacePath)); err != nil {
		return err
	}

	if err := a.WaitForJunctionToRemove(junctionNameSpacePath); err != nil {
		return err
	}

	if err := a.DeleteExportPolicyIfExists(junctionNameSpacePath); err != nil {
		return err
	}

	log.Printf("[INFO] vfxt: ensure stable cluster after deleting junction")
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) SetSupportName() error {
	if _, err := a.AvereCommand(a.getSupportModifySetCustomerIdCommand()); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) EnableSupport() error {
	if a.EnableSupportUploads {
		if _, err := a.AvereCommand(a.getSupportAcceptTermsCommand()); err != nil {
			return err
		}
		if _, err := a.AvereCommand(a.getSupportSupportTestUploadCommand()); err != nil {
			return err
		}
	}
	return nil
}

func (a *AvereVfxt) AreTermsAccepted() (bool, error) {
	jsonData, err := a.AvereCommand(a.getSupportAreTermsAccepted())
	if err != nil {
		return false, err
	}
	var termsAccepted bool
	if err := json.Unmarshal([]byte(jsonData), &termsAccepted); err != nil {
		return false, err
	}
	return termsAccepted, nil
}

func (a *AvereVfxt) ModifySupportUploads() error {
	if err := a.EnableSupport(); err != nil {
		return err
	}
	termsAccepted, err := a.AreTermsAccepted()
	if err != nil {
		return err
	}
	if termsAccepted {
		if _, err := a.AvereCommand(a.getSupportModifyCustomerUploadInfoCommand()); err != nil {
			return err
		}
		if _, err := a.AvereCommand(a.getSupportSecureProactiveSupportCommand()); err != nil {
			return err
		}
	}
	return nil
}

func (a *AvereVfxt) GetCoreFilerSpacePercentage() (map[string]float32, error) {
	jsonData, err := a.AvereCommand(a.getAnalyticsCoreFilerSpaceCommand())
	if err != nil {
		return nil, err
	}

	var outputParts [][]interface{}
	if err := json.Unmarshal([]byte(jsonData), &outputParts); err != nil {
		return nil, err
	}

	if len(outputParts) <= 1 && len(outputParts[1]) < 1 {
		return nil, fmt.Errorf("json did not parse correctly and is less than two parts: '%v'", jsonData)
	}

	analytics := (outputParts[1][0]).(map[string]interface{})

	rawFreeSpace, ok := analytics[AnalyticsClusterFilersRaw]
	if !ok {
		return nil, fmt.Errorf("key %s not found in analytics", AnalyticsClusterFilersRaw)
	}

	rawJson, err := json.Marshal(rawFreeSpace)
	if err != nil {
		return nil, err
	}

	var freeSpaceMap map[string]ClusterFilersRaw
	if err := json.Unmarshal(rawJson, &freeSpaceMap); err != nil {
		return nil, err
	}

	var totalSpace float32
	for _, v := range freeSpaceMap {
		totalSpace += float32(v.AvailableForReads)
	}

	result := make(map[string]float32)
	for k, v := range freeSpaceMap {
		result[k] = float32(v.AvailableForReads) / totalSpace
	}

	return result, nil
}

func IsMultiCall(cmd string) bool {
	return strings.Contains(cmd, MultiCall)
}

func IsMultiCallResultSuccessful(result string) (bool, string, error) {
	if len(result) == 0 {
		return true, "", nil
	}

	var resultList []interface{}
	if err := json.Unmarshal([]byte(result), &resultList); err != nil {
		return false, "", err
	}
	for _, in := range resultList {
		switch v := in.(type) {
		case map[string]interface{}:
			if faultString, ok := v[FaultString]; ok {
				return false, fmt.Sprintf("fault encountered: %v", faultString), nil
			}
			if faultCode, ok := v[FaultCode]; ok {
				return false, fmt.Sprintf("fault encountered: %v", faultCode), nil
			}
		}
	}
	return true, "", nil
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
	}
}

// scale-down the cluster to the newNodeCount
func (a *AvereVfxt) scaleDownCluster(newNodeCount int) error {

	// the cluster should be stable before and after the removal of the cluster node
	if err := a.EnsureClusterStable(); err != nil {
		return err
	}

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

func (a *AvereVfxt) UploadSupportBundle() error {
	log.Printf("[INFO] [UploadSupportBundle")
	defer log.Printf("[INFO] UploadSupportBundle]")
	if _, err := a.AvereCommand(a.getUploadSupportBundleCommand()); err != nil {
		return err
	}
	return nil
}

func (a *AvereVfxt) UploadSupportBundleAndBlock() error {
	log.Printf("[INFO] [UploadSupportBundleAndBlock")
	defer log.Printf("[INFO] UploadSupportBundleAndBlock]")
	if err := a.UploadSupportBundle(); err != nil {
		return err
	}

	return a.BlockOnUploadSupportFiles()
}

func (a *AvereVfxt) UploadRollingTraceAndBlock() error {
	log.Printf("[INFO] [UploadRollingTrace")
	defer log.Printf("[INFO] UploadRollingTrace]")
	if a.EnableRollingTraceData {
		epoch := time.Now().Unix()
		if _, err := a.AvereCommand(a.getUploadRollingTraceCommand(epoch, RollingTraceTimeAfter, RollingTraceTimeBefore)); err != nil {
			return err
		}
		return a.BlockOnUploadSupportFiles()
	}
	return nil
}

func (a *AvereVfxt) BlockOnUploadSupportFiles() error {
	for retries := 1; ; retries++ {
		isUploading, err := a.IsUploadingSupportFiles()
		if err == nil && !isUploading {
			return nil
		}

		if retries > UploadGSIRetryCount {
			// don't wait longer than the specified time
			return err
		}
		log.Printf("[INFO] [%d / %d ] still uploading support files", retries, UploadGSIRetryCount)
		time.Sleep(UploadGSIRetrySleepSeconds * time.Second)
	}
}

func (a *AvereVfxt) IsUploadingSupportFiles() (bool, error) {
	uploadStatus, err := a.GetGSINodeStatus()
	if err != nil {
		return false, err
	}

	for _, s := range uploadStatus {
		if !strings.Contains(s.Status, "No support operations currently running") {
			return true, nil
		}
	}

	return false, nil
}

func (a *AvereVfxt) GetGSINodeStatus() ([]UploadStatus, error) {
	uploadStatusJson, err := a.AvereCommand(a.getGSINodeStatusJsonCommand())
	if err != nil {
		return nil, err
	}

	var outputParts [][]interface{}
	if err := json.Unmarshal([]byte(uploadStatusJson), &outputParts); err != nil {
		return nil, err
	}

	if len(outputParts) <= 1 && len(outputParts[1]) < 1 {
		return nil, fmt.Errorf("json did not parse correctly and is less than two parts: '%v'", uploadStatusJson)
	}

	statuses := (outputParts[1][0]).([]interface{})

	rawJson, err := json.Marshal(statuses)
	if err != nil {
		return nil, err
	}

	var results []UploadStatus
	if err := json.Unmarshal(rawJson, &results); err != nil {
		return nil, err
	}
	return results, nil
}

func (a *AvereVfxt) getListNodesJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json node.list", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveNodeCommand(node string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json system.multicall \"[{'methodName':'system.enableAPI','params':['maintenance']},{'methodName':'node.remove','params':['%s']}]\"", a.getBaseAvereCmd(), node), AverecmdLogFile)
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
	dnsServer := ""
	if len(a.DnsServer) > 0 {
		dnsServer = fmt.Sprintf(",'DNSserver':'%s'", a.DnsServer)
	}
	dnsDomain := ""
	if len(a.DnsDomain) > 0 {
		dnsDomain = fmt.Sprintf(",'DNSdomain':'%s'", a.DnsDomain)
	}
	dnsSearch := ""
	if len(a.DnsSearch) > 0 {
		dnsSearch = fmt.Sprintf(",'DNSsearch':'%s'", a.DnsSearch)
	}
	return WrapCommandForLogging(fmt.Sprintf("%s cluster.modify \"{'timezone':'%s'%s%s%s,'mgmtIP':{'IP': '%s','netmask':'%s','vlan':'%s'}}\"", a.getBaseAvereCmd(), a.Timezone, dnsServer, dnsDomain, dnsSearch, cluster.MgmtIP.IP, cluster.MgmtIP.Netmask, cluster.InternetVlan), AverecmdLogFile)
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

func (a *AvereVfxt) getEnableAPIMaintenanceCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s system.enableAPI maintenance", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getFilerJsonCommand(filer string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json corefiler.get \"%s\"", a.getBaseAvereCmd(), filer), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateCoreFilerCommand(coreFiler *CoreFiler) string {
	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.create \"%s\" \"%s\" true \"{'filerNetwork':'cluster','filerClass':'%s','cachePolicy':'%s',}\"", a.getBaseAvereCmd(), coreFiler.Name, coreFiler.FqdnOrPrimaryIp, coreFiler.FilerClass, coreFiler.CachePolicy), AverecmdLogFile)
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
	return WrapCommandForLogging(fmt.Sprintf("%s --json system.multicall \"[{'methodName':'system.enableAPI','params':['maintenance']},{'methodName':'corefiler.remove','params':['%s']}]\"", a.getBaseAvereCmd(), filer), AverecmdLogFile)
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

	return WrapCommandForLogging(fmt.Sprintf("%s corefiler.createCredential \"%s\" azure-storage \"{'note':'%s','storageKey':'BASE64:%s','tenant':'%s','subscription':'%s',}\"", a.getBaseAvereCmd(), azureStorageFiler.GetCloudFilerName(), TerraformAutoMessage, key, azureStorageFiler.AccountName, subscriptionId), AverecmdLogFile), nil
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

func (a *AvereVfxt) getListExportPoliciesJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json nfs.listPolicies \"%s\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateExportPolicyCommand(policyName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s nfs.addPolicy \"%s\" \"%s\"", a.getBaseAvereCmd(), VServerName, policyName), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteExportPolicyCommand(policyName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s nfs.removePolicy \"%s\" \"%s\"", a.getBaseAvereCmd(), VServerName, policyName), AverecmdLogFile)
}

func (a *AvereVfxt) getListExportRulesJsonCommand(policyName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json nfs.listRules \"%s\" \"%s\"", a.getBaseAvereCmd(), VServerName, policyName), AverecmdLogFile)
}

func (a *AvereVfxt) getCreateExportRuleCommand(policyName string, exportRule *ExportRule) string {
	return WrapCommandForLogging(fmt.Sprintf("%s nfs.addRule \"%s\" \"%s\" %s", a.getBaseAvereCmd(), VServerName, policyName, exportRule.NfsAddRuleArgumentsString()), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteExportRuleCommand(exportRuleId string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s nfs.removeRule \"%s\"", a.getBaseAvereCmd(), exportRuleId), AverecmdLogFile)
}

func (a *AvereVfxt) getListJunctionsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json vserver.listJunctions \"%s\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func getAccessControl(junction *Junction) (string, string) {
	sharename := ""
	mode := JunctionPolicyPosix
	if len(junction.CoreFilerCifsShareName) > 0 {
		sharename = junction.CoreFilerCifsShareName
		mode = JunctionPolicyCifs
	}
	return sharename, mode
}

func (a *AvereVfxt) getCreateJunctionCommand(junction *Junction, policyName string) string {
	inheritPolicy := "yes"
	if len(policyName) > 0 {
		inheritPolicy = "no"
	}
	sharename, mode := getAccessControl(junction)
	return WrapCommandForLogging(fmt.Sprintf("%s vserver.addJunction \"%s\" \"%s\" \"%s\" \"%s\" \"{'sharesubdir':'','inheritPolicy':'%s','sharename':'%s','access':'%s','createSubdirs':'yes','subdir':'%s','policy':'%s','permissions':'%s'}\"", a.getBaseAvereCmd(), VServerName, junction.NameSpacePath, junction.CoreFilerName, junction.CoreFilerExport, inheritPolicy, sharename, mode, junction.ExportSubdirectory, policyName, junction.SharePermissions), AverecmdLogFile)
}

func (a *AvereVfxt) getDeleteJunctionCommand(junctionNameSpacePath string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s vserver.removeJunction \"%s\" \"%s\"", a.getBaseAvereCmd(), VServerName, junctionNameSpacePath), AverecmdLogFile)
}

func (a *AvereVfxt) getListCustomSettingsJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json support.listCustomSettings", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSetCustomSettingCommand(customSetting string, message string) string {
	c := InitializeCustomSetting(customSetting)
	return WrapCommandForLogging(fmt.Sprintf("%s support.setCustomSetting %s \"%s\"", a.getBaseAvereCmd(), c.GetCustomSettingCommand(), message), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveCustomSettingCommand(customSetting string) string {
	firstArgument := GetCustomSettingName(customSetting)
	return WrapCommandForLogging(fmt.Sprintf("%s support.removeCustomSetting %s", a.getBaseAvereCmd(), firstArgument), AverecmdLogFile)
}

func (a *AvereVfxt) getSupportAreTermsAccepted() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json support.areTermsAccepted", a.getBaseAvereCmd()), AverecmdLogFile)
}

// This is activated by the customer accepting the privacy policy by setting enable_support_uploads.  Otherwise, none of the examples will ever set this.
func (a *AvereVfxt) getSupportAcceptTermsCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.acceptTerms yes", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSupportSupportTestUploadCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.testUpload", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getAnalyticsCoreFilerSpaceCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json system.multicall \"[{'methodName':'system.enableAPI','params':['internal']},{'methodName':'analytics.getCoreFilerCacheSpaceData','params':[]}]\"", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSupportModifySetCustomerIdCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.modify \"{'customerId':'%s'}\"", a.getBaseAvereCmd(), a.AvereVfxtSupportName), AverecmdLogFile)
}

func (a *AvereVfxt) getSetClusterNameCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s cluster.modify \"{'name':'%s'}\"", a.getBaseAvereCmd(), a.AvereVfxtName), AverecmdLogFile)
}

// this updates support uploads per docs https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-enable-support
func (a *AvereVfxt) getSupportModifyCustomerUploadInfoCommand() string {
	isEnabled := "no"
	rollingTrace := "no"
	traceLevel := "0x1"
	if a.EnableSupportUploads {
		isEnabled = "yes"
		if a.EnableRollingTraceData {
			rollingTrace = "yes"
			traceLevel = a.RollingTraceFlag
		}
	}
	return WrapCommandForLogging(fmt.Sprintf("%s support.modify \"{'crashInfo':'%s','corePolicy':'overwriteOldest','statsMonitor':'%s','rollingTrace':'%s','traceLevel':'%s','memoryDebugging':'no','generalInfo':'%s','customerId':'%s'}\"", a.getBaseAvereCmd(), isEnabled, isEnabled, rollingTrace, traceLevel, isEnabled, a.AvereVfxtSupportName), AverecmdLogFile)
}

// this updates SPS (Secure Proactive Support) per docs https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-enable-support
func (a *AvereVfxt) getSupportSecureProactiveSupportCommand() string {
	isEnabled := "no"
	secureProactiveSupport := ProactiveSupportDisabled
	if a.EnableSupportUploads {
		isEnabled = "yes"
		secureProactiveSupport = a.SecureProactiveSupport
	}
	return WrapCommandForLogging(fmt.Sprintf("%s support.modify \"{'remoteCommandEnabled':'%s','SPSLinkInterval':'60','SPSLinkEnabled':'%s','remoteCommandExpiration':''}\"", a.getBaseAvereCmd(), secureProactiveSupport, isEnabled), AverecmdLogFile)
}

func (a *AvereVfxt) getDirServicesEnableCIFSCommand() string {
	usernameSource := CIFSUsernameSourceAD
	structSuffix := ""
	flatFilePasswdUri := a.CifsFlatFilePasswdURI
	flatFileGroupUri := a.CifsFlatFileGroupURI
	if a.IsUsingFlatFiles() {
		flatFilePasswdUri = fmt.Sprintf(CIFSSelfPasswdUriStrFmt, a.ManagementIP)
		flatFileGroupUri = fmt.Sprintf(CIFSSelfGroupUriStrFmt, a.ManagementIP)
	}
	if len(flatFilePasswdUri) > 0 && len(flatFileGroupUri) > 0 {
		usernameSource = CIFSUsernameSourceFile
		structSuffix = fmt.Sprintf(",'usernamePasswdURI':'%s','usernameGroupURI':'%s'", flatFilePasswdUri, flatFileGroupUri)
	}

	return WrapCommandForLogging(fmt.Sprintf("%s dirServices.modify \"%s\" \"{'usernameMapSource':'None','usernameSource':'%s','DCsmbProtocol':'SMB2','netgroupSource':'None','usernameConditions':'enabled','ADdomainName':'%s','ADtrusted':'%s','nfsDomain':'','netgroupPollPeriod':'3600','usernamePollPeriod':'3600'%s}\"", a.getBaseAvereCmd(), DefaultDirectoryServiceName, usernameSource, a.CifsAdDomain, a.CifsTrustedActiveDirectoryDomains, structSuffix), AverecmdLogFile)
}

func (a *AvereVfxt) getDirServicesPollUserGroupCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s dirServices.usernamePoll \"%s\"", a.getBaseAvereCmd(), DefaultDirectoryServiceName), AverecmdLogFile)
}

func (a *AvereVfxt) getAddAdOverrideCommand(netbiosDomainName string, adFqdn string, dcAddresses string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s dirServices.addAdOverride \"%s\" \"%s\" \"%s\" \"%s\"", a.getBaseAvereCmd(), DefaultDirectoryServiceName, netbiosDomainName, adFqdn, dcAddresses), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveAdOverrideCommand(netbiosDomainName string, adFqdn string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s dirServices.removeAdOverride \"%s\" \"%s\" \"%s\"", a.getBaseAvereCmd(), DefaultDirectoryServiceName, netbiosDomainName, adFqdn), AverecmdLogFile)
}

func (a *AvereVfxt) getListAdOverrideJSONCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json dirServices.listAdOverrides \"%s\"", a.getBaseAvereCmd(), DefaultDirectoryServiceName), AverecmdLogFile)
}

func (a *AvereVfxt) getCIFSConfigureCommand() string {
	organizationalUnit := ""
	if len(a.CifsOrganizationalUnit) > 0 {
		organizationalUnit = fmt.Sprintf(",'%s'", a.CifsOrganizationalUnit)
	}
	// wrap in mutli-call since OU doesn't get picked up otherwise
	nonSecretCommand := fmt.Sprintf("%s --json system.multicall \"[{'methodName':'cifs.configure','params':['%s','%s','%s','%%s'%s]}]\"", a.getBaseAvereCmd(), VServerName, a.CifsServerName, a.CifsUsername, organizationalUnit)
	return WrapCommandForLoggingSecretInput(nonSecretCommand, fmt.Sprintf(nonSecretCommand, a.CifsPassword), AverecmdLogFile)
}

func (a *AvereVfxt) getCIFSSetOptionsCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.setOptions \"%s\" \"{'client_ntlmssp_disable':'no','disable_outbound_ntlmssp':'yes','smb2':'yes','ntlm_auth':'no','smb1':'no','read_only_optimized':'no','native_identity':'yes','server_signing':'auto'}\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getCIFSEnableCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.enable \"%s\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getCIFSDisableCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.disable \"%s\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getAddCIFSShareCommand(sharename string, namespaceName string, cifsCreateMask string, cifsDirMask string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.addShare \"%s\" \"%s\" \"/\" \"%s\" \"\" \"false\" \"{'create mask':'%s','security mask':'%s','directory mask':'%s','directory security mask':'%s'}\" ", a.getBaseAvereCmd(), VServerName, sharename, namespaceName, cifsCreateMask, cifsCreateMask, cifsDirMask, cifsDirMask), AverecmdLogFile)
}

func (a *AvereVfxt) getUpdateCIFSShareCommand(sharename string, cifsCreateMask string, cifsDirMask string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.modifyShare \"%s\" \"%s\" \"{'create mask':'%s','security mask':'%s','directory mask':'%s','directory security mask':'%s'}\" ", a.getBaseAvereCmd(), VServerName, sharename, cifsCreateMask, cifsCreateMask, cifsDirMask, cifsDirMask), AverecmdLogFile)
}

func (a *AvereVfxt) getRemoveCIFSShareCommand(sharename string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.removeShare \"%s\" \"%s\"", a.getBaseAvereCmd(), VServerName, sharename), AverecmdLogFile)
}

func (a *AvereVfxt) getListCIFSSharesJSONCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json cifs.listShares \"%s\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getGetShareAclsJSONCommand(sharename string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json cifs.getShareAcl \"%s\" \"%s\"", a.getBaseAvereCmd(), VServerName, sharename), AverecmdLogFile)
}

func (a *AvereVfxt) getGetAddShareAceCommand(sharename string, shareAce *ShareAce) string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.addShareAce '%s' '%s' %s", a.getBaseAvereCmd(), VServerName, sharename, shareAce.NfsAddRuleArgumentsString()), AverecmdLogFile)
}

func (a *AvereVfxt) getGetRemoveShareAceCommand(sharename string, shareAce *ShareAce) string {
	return WrapCommandForLogging(fmt.Sprintf("%s cifs.removeShareAce '%s' '%s' %s", a.getBaseAvereCmd(), VServerName, sharename, shareAce.NfsAddRuleArgumentsString()), AverecmdLogFile)
}

func (a *AvereVfxt) getEnableExtendedGroupsCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s nfs.modify \"%s\" \"{'extendedGroups':'yes'}\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getDisableExtendedGroupsCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s nfs.modify \"%s\" \"{'extendedGroups':'no'}\"", a.getBaseAvereCmd(), VServerName), AverecmdLogFile)
}

func (a *AvereVfxt) getDirServicesSetLdapPasswordCommand() string {
	nonSecretCommand := fmt.Sprintf("%s dirServices.setLdapPassword \"00000000-0000-0000-0000-000000000001\" \"%%s\"", a.getBaseAvereCmd())
	return WrapCommandForLoggingSecretInput(nonSecretCommand, fmt.Sprintf(nonSecretCommand, a.LoginServicesLDAPBindPassword), AverecmdLogFile)
}

func getEpochMilliseconds() int64 {
	now := time.Now()
	nanos := now.UnixNano()
	return nanos / 1000000
}

func (a *AvereVfxt) getDirServicesModifyCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s dirServices.modify \"00000000-0000-0000-0000-000000000001\" \"{'LDAPrequireCertificate':'enabled','LDAPbasedn':'%s','LDAPbinddn':'%s','loginSource':'Local/LDAP','LDAPserver':'%s','LDAPsecureAccess':'disabled','loginQueryAttributes':'ad','loginPollNow':'%v'}\"", a.getBaseAvereCmd(), a.LoginServicesLDAPBasedn, a.LoginServicesLDAPBinddn, a.LoginServicesLDAPServer, getEpochMilliseconds()), AverecmdLogFile)
}

func (a *AvereVfxt) getLoginSettingsDisableCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s dirServices.modify \"00000000-0000-0000-0000-000000000001\" \"{'LDAPrequireCertificate':'enabled','LDAPbasedn':'','loginSource':'Local','LDAPserver':'','LDAPsecureAccess':'disabled','LDAPbinddn':'','loginPollNow':'%v'}\"", a.getBaseAvereCmd(), getEpochMilliseconds()), AverecmdLogFile)
}

func (a *AvereVfxt) getUploadRollingTraceCommand(secondsSinceEpoch int64, aftermin int, beforemin int) string {
	return WrapCommandForLogging(fmt.Sprintf("%s  support.executeNormalMode cluster gsirollingtrace \"\" \"{'eventtime':'%d','aftermin':'%d','beforemin':'%d'}\"", a.getBaseAvereCmd(), secondsSinceEpoch, aftermin, beforemin), AverecmdLogFile)
}

func (a *AvereVfxt) getUploadSupportBundleCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s support.executeNormalMode cluster gsisupportbundle", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getGSINodeStatusJsonCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s --json system.multicall \"[{'methodName':'system.enableAPI','params':['internal']},{'methodName':'support.getGSINodeStatus','params':[]}]\"", a.getBaseAvereCmd()), AverecmdLogFile)
}

func (a *AvereVfxt) getSetVServerSettingCommand(customSetting string, message string) string {
	vServerCustomSetting := GetVServerCustomSetting(customSetting)
	return a.getSetCustomSettingCommand(vServerCustomSetting, message)
}

func (a *AvereVfxt) getRemoveVServerSettingCommand(customSetting string) string {
	vServerCustomSetting := GetVServerCustomSetting(customSetting)
	return a.getRemoveCustomSettingCommand(vServerCustomSetting)
}

func (a *AvereVfxt) getSetFilerSettingCommand(internalName string, customSetting *CustomSetting, message string) string {
	coreFilerCustomSetting := GetFilerCustomSetting(internalName, customSetting.GetCustomSettingCommand())
	return a.getSetCustomSettingCommand(coreFilerCustomSetting, message)
}

func (a *AvereVfxt) getRemoveFilerSettingCommand(customSettingName string) string {
	return a.getRemoveCustomSettingCommand(customSettingName)
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

func GetPingIPAddressesCommand(startQuartet int, endQuartet int, addressPrefix string) string {
	// '|| true' is added to the end since we want the result to be 0
	// and collect the resulting stdout
	return WrapCommandForLogging(fmt.Sprintf("for ip in $(seq %d %d); do nc -n -v -z -w 1 %s$ip 443 2>&1 |grep timed; done || true", startQuartet, endQuartet, addressPrefix), ShellLogFile)
}

func getEnsureSSHPass() string {
	return WrapCommandForLogging("which sshpass || sudo apt-get install -y sshpass", ShellLogFile)
}

func getEnsureNoKnownHosts() string {
	return WrapCommandForLogging("rm -f ~/.ssh/known_hosts", ShellLogFile)
}

func (a *AvereVfxt) GetSSHPassPrefix() string {
	return fmt.Sprintf("sshpass -p '%s' ", a.AvereAdminPassword)
}

func (a *AvereVfxt) GetBaseVFXTNodeCommand() string {
	return a.GetBaseVFXTNodeCommandWithIPAddress(a.ManagementIP)
}

func (a *AvereVfxt) GetBaseVFXTNodeCommandWithIPAddress(ipAddress string) string {
	sshPassPrefix := a.GetSSHPassPrefix()
	return fmt.Sprintf("%s ssh -oStrictHostKeyChecking=no -oProxyCommand=\"%s ssh -oStrictHostKeyChecking=no -W %%h:%%p admin@%s\" root@localhost ", sshPassPrefix, sshPassPrefix, ipAddress)
}

func (a *AvereVfxt) getPutPasswdFileCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("echo %s | base64 -d | gunzip > ~/avere-user.txt", a.CifsFlatFilePasswdB64z), ShellLogFile)
}

func (a *AvereVfxt) getPutGroupFileCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("echo %s | base64 -d | gunzip > ~/avere-group.txt", a.CifsFlatFileGroupB64z), ShellLogFile)
}

func (a *AvereVfxt) getFlatFileScpCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s scp -oStrictHostKeyChecking=no ~/avere-* admin@%s:/tmp ", a.GetSSHPassPrefix(), a.ManagementIP), ShellLogFile)
}

func (a *AvereVfxt) getCleanFlatFileCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"rm -f /tmp/avere-*.txt\"'", a.GetBaseVFXTNodeCommand()), ShellLogFile)
}

func (a *AvereVfxt) getCopyPasswdFileCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"clustercp.py /tmp/avere-user.txt /usr/local/www/apache24/data/avere/avere-user.txt\"'", a.GetBaseVFXTNodeCommand()), ShellLogFile)
}

func (a *AvereVfxt) getCopyGroupFileCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"clustercp.py /tmp/avere-group.txt /usr/local/www/apache24/data/avere/avere-group.txt\"'", a.GetBaseVFXTNodeCommand()), ShellLogFile)
}

func (a *AvereVfxt) getMakeVFXTWritableCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"clusterexec.py mount -uw /\"'", a.GetBaseVFXTNodeCommand()), ShellLogFile)
}

func (a *AvereVfxt) getMakeVFXTReadonlyCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"clusterexec.py mount -ur /\"'", a.GetBaseVFXTNodeCommand()), ShellLogFile)
}

func (a *AvereVfxt) getSetServerAddrCommand(internalName string, coreFileIPStr string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"dbutil.py set %s serverAddr '\"'\"'%s'\"'\"' -x\"'", a.GetBaseVFXTNodeCommand(), internalName, coreFileIPStr), ShellLogFile)
}

func (a *AvereVfxt) getPutRidGeneratorCommand(ridGeneratorFileB64z string) string {
	return WrapCommandForLogging(fmt.Sprintf("echo %s | base64 -d | gunzip > ~/generate-rid-avereflatfiles.py", ridGeneratorFileB64z), ShellLogFile)
}

func (a *AvereVfxt) getRidGeneratorScpCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s scp -oStrictHostKeyChecking=no ~/generate-rid-avereflatfiles.py admin@%s:/tmp ", a.GetSSHPassPrefix(), a.ManagementIP), ShellLogFile)
}

func (a *AvereVfxt) getExecuteRidGeneratorCommand() string {
	nonSecretBase := fmt.Sprintf("%%s 'bash -l -c \"python /tmp/generate-rid-avereflatfiles.py %s '\"'\"'%s'\"'\"' '\"'\"'%%s'\"'\"' %d /tmp/avere-user.txt /tmp/avere-group.txt\"'", a.CifsAdDomain, a.CifsUsername, a.CifsRidMappingBaseInteger)
	nonSecretCommand := fmt.Sprintf(nonSecretBase, a.GetBaseVFXTNodeCommand(), "***")
	secretCommand := fmt.Sprintf(nonSecretBase, a.GetBaseVFXTNodeCommand(), a.CifsPassword)
	return WrapCommandForLoggingSecretInput(nonSecretCommand, secretCommand, ShellLogFile)
}

func (a *AvereVfxt) getSetGSIUploadUrlCommand(url string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"dbutil.py set gsiInfo url %s --user admin --case latency\"'", a.GetBaseVFXTNodeCommand(), url), ShellLogFile)
}

func (a *AvereVfxt) getVServerInternalNamesCommand() string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"lsu vservers\"'", a.GetBaseVFXTNodeCommand()), ShellLogFile)
}

func (a *AvereVfxt) getVServerNameCommand(internalVServerName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"lsu %s name|cut -d '\"'\"' '\"'\"' -f 2\"'", a.GetBaseVFXTNodeCommand(), internalVServerName), ShellLogFile)
}

func (a *AvereVfxt) getServerNlmNoProbeCommand(internalVServerName string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"dbutil.py get %s serverNlmNoProbe\"'", a.GetBaseVFXTNodeCommand(), internalVServerName), ShellLogFile)
}

func (a *AvereVfxt) getSetServerNlmNoProbeCommand(internalVServerName string, dbutilValue string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"dbutil.py set %s serverNlmNoProbe %s --user admin --case nlmadjust\"'", a.GetBaseVFXTNodeCommand(), internalVServerName, dbutilValue), ShellLogFile)
}

func (a *AvereVfxt) getSetServerNlm(internalVServerName string, dbutilValue string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"dbutil.py set %s serverNlm %s --user admin --case nlmadjust\"'", a.GetBaseVFXTNodeCommand(), internalVServerName, dbutilValue), ShellLogFile)
}

func (a *AvereVfxt) getRestartArmadaCommand(staticIP string) string {
	return WrapCommandForLogging(fmt.Sprintf("%s 'bash -l -c \"clusterexec.py /etc/rc.d/armadad restart\"'", a.GetBaseVFXTNodeCommandWithIPAddress(staticIP)), ShellLogFile)
}
