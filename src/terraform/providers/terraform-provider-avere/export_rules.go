package main

import (
	"fmt"
	"net"
	"regexp"
	"strings"
)

const (
	ExportDefaultPolicy = "default"
	ExportDefaultAll    = "*"

	ExportPolicyNameFormat = "tfauto_%s%s"

	ExportRuleScopeHost    = "host"
	ExportRuleScopeNetwork = "network"
	ExportRuleScopeDefault = "default"

	ExportAccessReadOnly  = "ro"
	ExportAccessReadWrite = "rw"
	ExportAccessDefault   = ExportAccessReadOnly

	ExportSquashAll        = "all_squash"
	ExportSquashAllArg     = "all"
	ExportSquashRoot       = "root_squash"
	ExportSquashRootArg    = "root"
	ExportSquashNone       = "no_root_squash"
	ExportSquashNoneArg    = "no"
	ExportSquashDefaultArg = ExportSquashAllArg

	ExportBoolArgYes = "yes"
	ExportBoolArgNo  = "no"

	ExportAllowSuid        = "allow_suid"
	ExportAllowSuidDefault = ExportBoolArgNo

	ExportAllowSubmounts        = "allow_submounts"
	ExportAllowSubmountsDefault = ExportBoolArgNo
)

type ExportRule struct {
	Filter         string `json:"filter"`
	FilterScope    string `json:"scope"`
	ExportAccess   string `json:"access"`
	ExportSquash   string `json:"squash"`
	AllowSuid      string `json:"suid"`
	AllowSubmounts string `json:"subdir"`
}

var matchExportRuleRegexp = regexp.MustCompile(`^([^\s\(\)]+(\([^\(\)]*\))?\s?)*$`)
var matchExportRulePartsRexexp = regexp.MustCompile(`(?:([^\s\(\)]+)(\([^\(\)]*\))?)`)
var matchDomainName = regexp.MustCompile(`^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$`)

func (r *ExportRule) String() string {
	return fmt.Sprintf("%s, %s, %s, %s, allowSuid %s, allowSubmounts %s", r.Filter, r.FilterScope, r.ExportAccess, r.ExportSquash, r.AllowSuid, r.AllowSubmounts)
}

func (r *ExportRule) NfsAddRuleArgumentsString() string {
	return fmt.Sprintf("\"%s\" \"%s\" \"%s\" \"%s\" -2 \"%s\" \"%s\" \"{'authKrb':'no','authSys':'yes'}\"", r.FilterScope, r.Filter, r.ExportAccess, r.ExportSquash, r.AllowSuid, r.AllowSubmounts)
}

func ExportRulesEqual(a, b map[string]*ExportRule) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		vb, ok := b[k]
		if !ok {
			return false
		}
		if *v != *vb {
			return false
		}
	}
	return true
}

func ParseExportRules(exportRule string) (map[string]*ExportRule, error) {
	// validate the rule itself with a regex
	if !matchExportRuleRegexp.MatchString(exportRule) {
		return nil, fmt.Errorf("the string '%s' is missing a host or parenthesis not closed, and should be of the format '<host1>(<options>) <host2>(<options>)...' ", exportRule)
	}

	var errors strings.Builder
	result := make(map[string]*ExportRule)

	// split up into parts
	allMatches := matchExportRulePartsRexexp.FindAllStringSubmatch(exportRule, -1)
	for _, match := range allMatches {
		// the regular expression only has 2 parts, but verify
		if len(match) != 3 {
			return nil, fmt.Errorf("[BUG] error the regular expression submatch should have exactly 3 parts: %v", match)
		}
		host := match[1]
		rules := match[2]

		exportRule := &ExportRule{}
		errorsExist := false

		if filter, filterScope, err := parseHost(host); err == nil {
			exportRule.Filter = filter
			exportRule.FilterScope = filterScope
		} else {
			errorsExist = true
			errors.WriteString(fmt.Sprintf("host error: '%v' ", err))
		}

		if exportAccess, exportSquash, allowSuid, allowSubmounts, err := parseRules(rules); err == nil {
			exportRule.ExportAccess = exportAccess
			exportRule.ExportSquash = exportSquash
			exportRule.AllowSuid = allowSuid
			exportRule.AllowSubmounts = allowSubmounts
		} else {
			errorsExist = true
			errors.WriteString(fmt.Sprintf("rules error: '%v' ", err))
		}

		if errorsExist == false {
			if _, ok := result[exportRule.Filter]; ok {
				errors.WriteString(fmt.Sprintf("host already exists: '%v' ", exportRule.Filter))
			} else {
				result[exportRule.Filter] = exportRule
			}
		}
	}

	if errors.Len() > 0 {
		return nil, fmt.Errorf(errors.String())
	}

	return result, nil
}

func parseHost(host string) (string, string, error) {
	trimmedHost := strings.TrimSpace(host)

	if trimmedHost == ExportDefaultAll {
		return trimmedHost, ExportRuleScopeDefault, nil
	}

	if _, _, err := net.ParseCIDR(host); err == nil {
		return host, ExportRuleScopeNetwork, nil
	}

	if ip := net.ParseIP(host); ip != nil {
		return host, ExportRuleScopeHost, nil
	}

	if !matchDomainName.MatchString(host) {
		return "", "", fmt.Errorf("invalid filter '%s', must be either '*', ip address, ip address with mask, or domain name", host)
	}

	return host, ExportRuleScopeHost, nil
}

func parseRules(rules string) (exportAccess string, exportSquash string, allowSuid string, allowSubmounts string, err error) {
	exportAccess = ExportAccessDefault
	exportSquash = ExportSquashDefaultArg
	allowSuid = ExportAllowSuidDefault
	allowSubmounts = ExportAllowSubmountsDefault

	var errors strings.Builder

	trimmedRule := strings.Trim(strings.TrimSpace(rules), "()")
	ruleList := strings.Split(trimmedRule, ",")
	for _, r := range ruleList {
		r = strings.TrimSpace(r)
		switch r {
		case ExportAccessReadOnly:
			exportAccess = ExportAccessReadOnly
		case ExportAccessReadWrite:
			exportAccess = ExportAccessReadWrite
		case ExportSquashAll:
			exportSquash = ExportSquashAllArg
		case ExportSquashRoot:
			exportSquash = ExportSquashRootArg
		case ExportSquashNone:
			exportSquash = ExportSquashNoneArg
		case ExportAllowSuid:
			allowSuid = ExportBoolArgYes
		case ExportAllowSubmounts:
			allowSubmounts = ExportBoolArgYes
		case "":
			continue
		default:
			errors.WriteString(fmt.Sprintf("invalid rule: '%s' ", r))
		}
	}

	if errors.Len() > 0 {
		err = fmt.Errorf(errors.String())
	}

	return exportAccess, exportSquash, allowSuid, allowSubmounts, err
}
