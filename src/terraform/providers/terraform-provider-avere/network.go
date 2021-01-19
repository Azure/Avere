// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"bytes"
	"fmt"
	"net"
	"sort"
	"strings"
)

func GetLastIPAddress(firstIp string, ipAddressCount int) (string, error) {
	// a.b.c.d where a==0, b==1, c==2, d==3
	d := 3

	ip := net.ParseIP(firstIp)
	if ip == nil {
		return "", fmt.Errorf("expected first IP '%s' to contain a valid IP address", firstIp)
	}
	ipv4 := ip.To4()
	if ipv4 == nil {
		return "", fmt.Errorf("expected first IP '%s' to contain a valid IPv4 address", firstIp)
	}

	// subtract 1 from ip count since we already have the ip address of the first node
	for i := 0; i < (ipAddressCount - 1); i++ {
		ipv4[d]++
		if ipv4[d] == 0 {
			return "", fmt.Errorf("overflow happened while finding the last ip address using nodecount of %d and first ip address of %s", ipAddressCount, firstIp)
		}
	}
	if (ipv4[d] + 1) == 0 {
		return "", fmt.Errorf("last IP address %s ended on the broadcast address using nodecount of %d and first ip address of %s", ipv4.String(), ipAddressCount, firstIp)
	}
	return ipv4.String(), nil
}

func GetIPAddressLastQuartet(ipAddress string) (int, error) {
	// a.b.c.d where a==0, b==1, c==2, d==3
	d := 3

	ip := net.ParseIP(ipAddress)
	if ip == nil {
		return 0, fmt.Errorf("address '%s' is invalid", ipAddress)
	}
	ipv4 := ip.To4()
	if ipv4 == nil {
		return 0, fmt.Errorf("address '%s' is an invalid IPv4 address", ipAddress)
	}

	return int(ipv4[d]), nil
}

func GetIPAddress3QuartetPrefix(ipAddress string) (string, error) {
	// a.b.c.d where a==0, b==1, c==2, d==3
	a := 0
	b := 1
	c := 2

	ip := net.ParseIP(ipAddress)
	if ip == nil {
		return "", fmt.Errorf("address '%s' is invalid", ipAddress)
	}
	ipv4 := ip.To4()
	if ipv4 == nil {
		return "", fmt.Errorf("address '%s' is an invalid IPv4 address", ipAddress)
	}

	return fmt.Sprintf("%d.%d.%d.", ipv4[a], ipv4[b], ipv4[c]), nil
}

func GetOrderedIPAddressList(ipAddressString string) []string {
	results := []string{}

	for _, ipAddr := range strings.Split(ipAddressString, " ") {
		trimmedIpAddr := strings.TrimSpace(ipAddr)
		if len(trimmedIpAddr) > 0 {
			results = append(results, trimmedIpAddr)
		}
	}

	return SortIPv4s(results)
}

// sort IPv4s, silently drop bad ips, and return a list of IPv4s
func SortIPv4s(ips []string) []string {
	sort.Strings(ips)

	ipAddresses := make([]net.IP, 0, len(ips))
	for _, s := range ips {
		ip := net.ParseIP(s)
		if ip != nil {
			if ipv4 := ip.To4(); ipv4 != nil {
				ipAddresses = append(ipAddresses, ip)
			}
		}
	}

	sort.Slice(ipAddresses, func(i, j int) bool {
		return bytes.Compare(ipAddresses[i], ipAddresses[j]) < 0
	})

	results := make([]string, 0, len(ips))
	for _, i := range ipAddresses {
		results = append(results, i.String())
	}
	return results
}

func GetContiguousIPSlices(ips []string) [][]string {
	// a.b.c.d where a==0, b==1, c==2, d==3
	a := 0
	b := 1
	c := 2
	d := 3

	sortedIPs := SortIPv4s(ips)

	results := make([][]string, 0, len(sortedIPs))

	if len(sortedIPs) > 0 {
		firstIPStr := sortedIPs[0]
		lastIPStr := firstIPStr
		firstIP := net.ParseIP(firstIPStr).To4() // no check for nil, b/c SortIPv4s returns correct list
		lastIP := firstIP
		for i := 1; i < len(sortedIPs); i++ {
			newLastIPStr := sortedIPs[i]
			newLastIp := net.ParseIP(newLastIPStr).To4() // no check for nil, b/c SortIPv4s returns correct list
			if lastIP[a] != newLastIp[a] || lastIP[b] != newLastIp[b] || lastIP[c] != newLastIp[c] || (newLastIp[d]-lastIP[d]) > 1 {
				results = append(results, []string{firstIPStr, lastIPStr})
				firstIPStr = newLastIPStr
				firstIP = newLastIp
			}
			lastIPStr = newLastIPStr
			lastIP = newLastIp
		}
		results = append(results, []string{firstIPStr, lastIPStr})
	}

	return results
}
