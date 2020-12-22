// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
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
	if ipv4 := ip.To4(); ipv4 == nil {
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
	if ipv4 := ip.To4(); ipv4 == nil {
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
	if ipv4 := ip.To4(); ipv4 == nil {
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

	sort.Strings(results)

	return results
}
