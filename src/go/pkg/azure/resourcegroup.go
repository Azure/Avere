// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
// Package azure implements various azure tools
package azure

import (
	"context"
	"fmt"
	"strconv"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-sdk-for-go/services/resources/mgmt/2019-03-01/resources"
	"github.com/Azure/go-autorest/autorest"
)

type ResourceGroup struct {
	GroupsClient resources.GroupsClient
	Context      context.Context
}

func InitializeResourceGroup(ctx context.Context, authorizer autorest.Authorizer, subscriptionId string) *ResourceGroup {
	groupsClient := resources.NewGroupsClient(subscriptionId)
	groupsClient.Authorizer = authorizer

	return &ResourceGroup{
		GroupsClient: groupsClient,
		Context:      ctx,
	}
}

func (rg *ResourceGroup) GetResourceGroupIntTag(resourceGroupName string, tagName string) (int, error) {
	log.Debug.Printf("[VMScaler.GetResourceGroupIntTag")
	defer log.Debug.Printf("VMScaler.GetResourceGroupIntTag]")

	group, err := rg.GroupsClient.Get(rg.Context, resourceGroupName)
	if err != nil {
		return 0, err
	}
	val, ok := group.Tags[tagName]
	if !ok {
		return 0, fmt.Errorf("no tag %s found for resource group %s", tagName, resourceGroupName)
	}
	i, err := strconv.ParseInt(*val, 10, 64)
	if err != nil {
		return 0, err
	}

	return int(i), nil
}

func (rg *ResourceGroup) SetTotalNodesIntTag(resourceGroupName string, tagName string, val int) (*resources.Group, error) {
	log.Debug.Printf("[VMScaler.SetTotalNodesIntTag")
	defer log.Debug.Printf("VMScaler.SetTotalNodesIntTag]")

	group, err := rg.GroupsClient.Get(rg.Context, resourceGroupName)
	if err != nil {
		return nil, err
	}
	valStr := strconv.Itoa(val)
	group.Tags[tagName] = &valStr
	// set the READ-ONLY property
	group.Properties = nil
	newGroup, err := rg.GroupsClient.CreateOrUpdate(
		rg.Context,
		resourceGroupName,
		group)
	if err != nil {
		return &group, err
	}
	return &newGroup, nil
}
