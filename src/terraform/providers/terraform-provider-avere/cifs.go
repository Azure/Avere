// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"path"
	"regexp"
	"strings"
)

const (
	AceDefaultAll           = "Everyone"
	AceDefaultAllType       = AceTypeAllow
	AceDefaultAllPermission = AcePermissionFull

	AceDefault = "Everyone(ALLOW,FULL)"

	AcePermissionRead    = "READ"
	AcePermissionChange  = "CHANGE"
	AcePermissionFull    = "FULL"
	AcePermissionDefault = AcePermissionRead

	AceTypeAllow   = "ALLOW"
	AceTypeDeny    = "DENY"
	AceTypeDefault = AceTypeAllow
)

type ShareAce struct {
	Name       string `json:"name"`
	Type       string `json:"type"`
	Permission string `json:"perm"`
	Sid        string `json:"sid"`
}

var matchAceRegexp = regexp.MustCompile(`^([^\s\(\)]+(\([^\(\)]*\))?\s?)*$`)
var matchAcePartsRexexp = regexp.MustCompile(`(?:([^\s\(\)]+)(\([^\(\)]*\))?)`)

// from https://stackoverflow.com/questions/42205107/regex-for-computer-name-validation-cannot-be-more-than-15-characters-long-be-e
var cifsServerNameRegexp = regexp.MustCompile(`^[a-zA-Z0-9-]{1,15}$`)
var cifsUsernameRegexp = regexp.MustCompile(`^[A-Za-z0-9\\\._\-#]{2,}$`)
var cifsShareRegexp = regexp.MustCompile(`^[A-Za-z0-9\._\-$]{1,}$`)
var cifsOrganizationalUnitRegExp = regexp.MustCompile(`^(?:(?:CN|OU|DC)\=[^,'"]+,)*(?:CN|OU|DC)\=[^,'"]+$`)
var cifsMaskRegexp = regexp.MustCompile(`^[0-7]{4}$`)

// simple fqdn regex from O'Reilly https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch08s15.html
var fqdnRegexp = regexp.MustCompile(`^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$`)

func (s *ShareAce) String() string {
	return fmt.Sprintf("%s(%s), %s, %s", s.Name, s.Sid, s.Type, s.Permission)
}

func (s *ShareAce) NfsAddRuleArgumentsString() string {
	// double quotes in properties needed to handle '\' in name, for example a user defined as rendering\azureuser
	return fmt.Sprintf("'{\"type\":\"%s\",\"id\":\"%s\",\"perm\":\"%s\"}'", s.Type, s.Name, s.Permission)
}

func InitializeCleanAce(ace *ShareAce) *ShareAce {
	cleanAce := ShareAce{}
	cleanAce = *ace
	cleanAce.Name = cleanCifsUserGroup(ace.Name)
	return &cleanAce
}

func NormalizeShareAces(shareAces map[string]*ShareAce) map[string]*ShareAce {
	results := make(map[string]*ShareAce)
	for _, v := range shareAces {
		if len(v.Name) > 0 {
			results[v.Name] = v
			// this resolves a case where the domain is put on afterwards
			// for example "azureuser" => "rendering\azureuser"
			// there is loss of information and "rendering\azureuser" will get seen as "rendering2\azureuser"
			nameWithoutDomain := removeDomain(v.Name)
			if len(nameWithoutDomain) < len(v.Name) {
				results[nameWithoutDomain] = v
			}
		}
		if len(v.Sid) > 0 {
			results[v.Sid] = v
		}
	}
	return results
}

func ShareAceIsEveryoneDefault(a *ShareAce) bool {
	return a.Name == AceDefaultAll && a.Type == AceDefaultAllType && a.Permission == AceDefaultAllPermission
}

func ShareAcesAreEveryone(a map[string]*ShareAce) bool {
	if len(a) == 1 {
		for _, v := range a {
			if !ShareAceIsEveryoneDefault(v) {
				return false
			}
		}
		return true
	} else {
		return false
	}
}

func ShareAcesEqual(a, b map[string]*ShareAce) bool {
	if ShareAcesAreEveryone(a) && ShareAcesAreEveryone(b) {
		return true
	}
	if len(a) != len(b) {
		return false
	}

	bmap := NormalizeShareAces(b)
	amap := NormalizeShareAces(a)

	// cross way check, because of normalization we just need one way equal
	crossWayA := true
	for k, v := range a {
		vb, ok := bmap[k]
		if !ok {
			vb, ok = bmap[removeDomain(k)]
			if !ok {
				crossWayA = false
				break
			}
		}
		if v.Type != vb.Type || v.Permission != vb.Permission {
			crossWayA = false
			break
		}
	}
	crossWayB := true
	for k, v := range b {
		va, ok := amap[k]
		if !ok {
			va, ok = amap[removeDomain(k)]
			if !ok {
				crossWayB = false
				break
			}
		}
		if v.Type != va.Type || v.Permission != va.Permission {
			crossWayB = false
			break
		}
	}

	return crossWayA || crossWayB
}

func removeDomain(userGroup string) string {
	if strings.Contains(userGroup, "\\") {
		return userGroup[strings.LastIndex(userGroup, "\\")+1:]
	}
	return userGroup
}

func ParseShareAces(ace string) (map[string]*ShareAce, error) {
	// validate the ace itself with a regex
	if !matchAceRegexp.MatchString(ace) {
		return nil, fmt.Errorf("the string '%s' is missing a user/group or parenthesis not closed, and should be of the format 'user/group(<options>) user/group(<options>)...' ", ace)
	}

	var errors strings.Builder
	result := make(map[string]*ShareAce)

	// split up into parts
	allMatches := matchAcePartsRexexp.FindAllStringSubmatch(ace, -1)
	for _, match := range allMatches {
		// the regular expression only has 2 parts, but verify
		if len(match) != 3 {
			return nil, fmt.Errorf("[BUG] error the regular expression submatch should have exactly 3 parts: %v", match)
		}
		userGroup := match[1]
		acePermissions := match[2]

		shareAce := &ShareAce{}
		errorsExist := false

		if name, err := parseUserGroup(userGroup); err == nil {
			shareAce.Name = name
		} else {
			errorsExist = true
			errors.WriteString(fmt.Sprintf("user/group error: '%v' ", err))
		}

		if aceType, acePermission, err := parseAcePermissions(acePermissions); err == nil {
			shareAce.Type = aceType
			shareAce.Permission = acePermission
		} else {
			errorsExist = true
			errors.WriteString(fmt.Sprintf("ace permissions error: '%v' ", err))
		}

		if errorsExist == false {
			if _, ok := result[shareAce.Name]; ok {
				errors.WriteString(fmt.Sprintf("user/group already exists: '%v' ", shareAce.Name))
			} else {
				cleanAce := InitializeCleanAce(shareAce)
				result[cleanAce.Name] = cleanAce
			}
		}
	}

	if errors.Len() > 0 {
		return nil, fmt.Errorf(errors.String())
	}

	return result, nil
}

func cleanCifsUserGroup(userGroup string) string {
	trimmedUserGroup := strings.TrimSpace(userGroup)
	// first replace \\ occurrences then \ occurrences
	trimmedUserGroupFwdSlash := strings.Replace(strings.Replace(trimmedUserGroup, "\\\\", "/", -1), "\\", "/", -1)
	return strings.Replace(trimmedUserGroupFwdSlash, "/", "\\\\", -1)
}

func parseUserGroup(userGroup string) (string, error) {
	updatedUserGroup := cleanCifsUserGroup(userGroup)

	if !cifsUsernameRegexp.MatchString(updatedUserGroup) {
		return "", fmt.Errorf("invalid ace '%s', must match windows user group name format", updatedUserGroup)
	}

	return updatedUserGroup, nil
}

func parseAcePermissions(rules string) (aceType string, acePermission string, err error) {
	aceType = AceTypeDefault
	acePermission = AcePermissionDefault

	var errors strings.Builder

	trimmedRule := strings.Trim(strings.TrimSpace(rules), "()")
	ruleList := strings.Split(trimmedRule, ",")
	for _, r := range ruleList {
		r = strings.TrimSpace(r)
		switch r {
		case AcePermissionRead:
			acePermission = AcePermissionRead
		case AcePermissionChange:
			acePermission = AcePermissionChange
		case AcePermissionFull:
			acePermission = AcePermissionFull
		case AceTypeAllow:
			aceType = AceTypeAllow
		case AceTypeDeny:
			aceType = AceTypeDeny
		case "":
			continue
		default:
			errors.WriteString(fmt.Sprintf("invalid ace permission: '%s' ", r))
		}
	}

	if errors.Len() > 0 {
		err = fmt.Errorf(errors.String())
	}

	return aceType, acePermission, err
}

func ValidateCIFSDomain(v interface{}, _ string) (warnings []string, errors []error) {
	host := v.(string)
	if !matchDomainName.MatchString(host) {
		errors = append(errors, fmt.Errorf("invalid domain name '%s'", host))
	}
	return warnings, errors
}

func ValidateCIFSServerName(v interface{}, _ string) (warnings []string, errors []error) {
	cifsServerName := v.(string)
	if !cifsServerNameRegexp.MatchString(cifsServerName) {
		errors = append(errors, fmt.Errorf("invalid cifs servername '%s'.  The name can be no longer than 15 characters.  Names can include alphanumeric characters (a-z, A-Z, 0-9) and hyphens(-).  For more information see https://github.com/Azure/Avere/tree/main/src/terraform/providers/terraform-provider-avere#cifs_server_name", cifsServerName))
	}
	return warnings, errors
}

func ValidateCIFSMask(v interface{}, _ string) (warnings []string, errors []error) {
	cifsServerName := v.(string)
	if len(cifsServerName) > 0 && !cifsMaskRegexp.MatchString(cifsServerName) {
		errors = append(errors, fmt.Errorf("invalid cifs mask '%s', it must be empty or a 4 digit octal number and match regex '%s'.", cifsServerName, cifsMaskRegexp))
	}
	return warnings, errors
}

func ValidateCIFSUsername(v interface{}, _ string) (warnings []string, errors []error) {
	cifsUsername := v.(string)
	parseError := ""
	if strings.Contains(cifsUsername, "@") {
		parts := strings.Split(cifsUsername, "@")
		if len(parts) == 2 {
			if !cifsUsernameRegexp.MatchString(parts[0]) {
				parseError = "bad username as subpart of full domain string"
			} else if !fqdnRegexp.MatchString(parts[1]) {
				parseError = "bad domain_fqdn"
			}
		} else {
			parseError = "multiple @ symbols"
		}
	} else {
		if !cifsUsernameRegexp.MatchString(cifsUsername) {
			parseError = "bad username"
		}
	}

	if len(parseError) > 0 {
		errors = append(errors, fmt.Errorf("invalid cifs username '%s', failed with error '%s'.  The name can include alphanumeric characters (a-z, A-Z, 0-9), '.', '\\', '#', hyphens(-), and underscores and specified as username[@domain_fqdn] format.", cifsUsername, parseError))
	}

	return warnings, errors
}

func ValidateCIFSShareName(v interface{}, _ string) (warnings []string, errors []error) {
	cifsShare := v.(string)
	if !cifsShareRegexp.MatchString(cifsShare) {
		errors = append(errors, fmt.Errorf("invalid cifs share '%s'.  The name can include alphanumeric characters (a-z, A-Z, 0-9), '.', hyphens(-), '$', and underscores.", cifsShare))
	}
	return warnings, errors
}

func ValidateCIFSShareAce(v interface{}, _ string) (warnings []string, errors []error) {
	input := v.(string)

	if len(input) > 0 {
		if _, err := ParseShareAces(input); err != nil {
			errors = append(errors, err)
		}
	}

	return warnings, errors
}

func ValidateOrganizationalUnit(v interface{}, _ string) (warnings []string, errors []error) {
	oranizationalUnit := v.(string)
	if !cifsOrganizationalUnitRegExp.MatchString(oranizationalUnit) {
		errors = append(errors, fmt.Errorf("invalid organizational unit share '%s'.  The name must match regular expression '%s'.", oranizationalUnit, cifsOrganizationalUnitRegExp))
	}
	return warnings, errors
}

func (c *CifsShare) GetNameSpacePath() string {
	return path.Join(c.Export, c.Suffix)
}

func GetShareAceAdjustments(existingShareAces map[string]*ShareAce, targetShareAces map[string]*ShareAce) ([]*ShareAce, []*ShareAce) {
	shareAcesToDelete := make([]*ShareAce, 0, len(existingShareAces))
	shareAcesToCreate := make([]*ShareAce, 0, len(targetShareAces))

	normalizedTargetShareAces := NormalizeShareAces(targetShareAces)
	for k, v := range existingShareAces {
		var ace *ShareAce
		var ok bool
		if ace, ok = normalizedTargetShareAces[k]; !ok {
			// try to remove the domain
			key2 := removeDomain(k)
			if ace, ok = normalizedTargetShareAces[key2]; !ok {
				ace = nil
			}
			// try to use the sid as a key
			key3 := v.Sid
			if ace, ok = normalizedTargetShareAces[key3]; !ok {
				ace = nil
			}
		}
		if ace == nil || !(ace.Type == v.Type && ace.Permission == v.Permission) {
			shareAcesToDelete = append(shareAcesToDelete, v)
		}
	}

	normalizedExistingShareAces := NormalizeShareAces(existingShareAces)
	for k, v := range targetShareAces {
		var ace *ShareAce
		var ok bool
		if ace, ok = normalizedExistingShareAces[k]; !ok {
			key2 := removeDomain(k)
			if ace, ok = normalizedExistingShareAces[key2]; ok {
				ace = nil
			}
		}
		if ace == nil || !(ace.Type == v.Type && ace.Permission == v.Permission) {
			shareAcesToCreate = append(shareAcesToCreate, v)
		}
	}

	return shareAcesToDelete, shareAcesToCreate
}
