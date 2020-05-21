// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"fmt"
	"net"
)

func GetLastIPAddress(firstIp string, nodeCount int) (string, error) {
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

	// subtract 1 from node count since we already have the ip address of the first node
	for i := 0; i < (nodeCount - 1); i++ {
		ipv4[d]++
		if ipv4[d] == 0 {
			return "", fmt.Errorf("overflow happened while finding the last ip address using nodecount of %d and first ip address of %s", nodeCount, firstIp)
		}
	}
	if (ipv4[d] + 1) == 0 {
		return "", fmt.Errorf("last IP address %s ended on the broadcast address using nodecount of %d and first ip address of %s", ipv4.String(), nodeCount, firstIp)
	}
	return ipv4.String(), nil
}
