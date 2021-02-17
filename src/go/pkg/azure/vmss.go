// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
// Package azure implements various azure tools
package azure

import (
	"context"
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"

	"github.com/Azure/azure-sdk-for-go/profiles/latest/compute/mgmt/compute"
	"github.com/Azure/go-autorest/autorest"
	"github.com/Azure/go-autorest/autorest/azure"
)

type Vmss struct {
	VmssClient compute.VirtualMachineScaleSetsClient
	Context    context.Context
}

func GetSubnetId(subscriptionId string, resourceGroupName string, vnetName string, subnetName string) string {
	return fmt.Sprintf("/subscriptions/%s/resourceGroups/%s/providers/Microsoft.Network/virtualNetworks/%s/subnets/%s", subscriptionId, resourceGroupName, vnetName, subnetName)
}

func InitializeVmss(ctx context.Context, authorizer autorest.Authorizer, subscriptionId string) *Vmss {
	vmssClient := compute.NewVirtualMachineScaleSetsClient(subscriptionId)
	vmssClient.Authorizer = authorizer

	// add usage guid per https://docs.microsoft.com/en-us/azure/marketplace/azure-partner-customer-usage-attribution#example-the-python-sdk
	if usageGuid, ok := GetUsageAttribution(ctx); ok {
		log.Info.Printf("Add usage guid %s to vmss client", usageGuid)
		vmssClient.AddToUserAgent(usageGuid)
	}

	return &Vmss{
		VmssClient: vmssClient,
		Context:    ctx,
	}
}

func (v *Vmss) ListVMSS(resourceGroupName string) ([]compute.VirtualMachineScaleSet, error) {
	var vmssList []compute.VirtualMachineScaleSet

	for subList, err := v.VmssClient.List(v.Context, resourceGroupName); subList.NotDone(); err = subList.Next() {
		if err != nil {
			return []compute.VirtualMachineScaleSet{}, err
		}
		vmssList = append(vmssList, subList.Values()...)
	}

	return vmssList, nil
}

func (v *Vmss) Create(resourceGroupName string, vmss compute.VirtualMachineScaleSet) (compute.VirtualMachineScaleSetsCreateOrUpdateFuture, error) {
	return v.VmssClient.CreateOrUpdate(v.Context, resourceGroupName, *vmss.Name, vmss)
}

func (v *Vmss) Update(resourceGroupName string, vmss compute.VirtualMachineScaleSet) (compute.VirtualMachineScaleSetsCreateOrUpdateFuture, error) {
	return v.VmssClient.CreateOrUpdate(v.Context, resourceGroupName, *vmss.Name, vmss)
}

type VmssOperationManager struct {
	Context       context.Context
	Client        autorest.Client
	vmssFutureMap map[string]*VmssOperation
	mux           sync.Mutex
}

type VmssOperation struct {
	LastQuery    time.Time
	WaitDuration time.Duration
	Attempts     int
	FutureAPI    azure.FutureAPI
}

func InitializeVmssOperationManager(ctx context.Context, client autorest.Client) *VmssOperationManager {
	return &VmssOperationManager{
		Context:       ctx,
		Client:        client,
		vmssFutureMap: make(map[string]*VmssOperation),
	}
}

const (
	tick            = time.Duration(1) * time.Second  // 1 second
	PrintStatsCycle = time.Duration(30) * time.Second // 30 seconds
)

func (v *VmssOperationManager) Run(syncWaitGroup *sync.WaitGroup) {
	defer syncWaitGroup.Done()

	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	lastStatssTime := time.Now().Add(-PrintStatsCycle)

	// loop around all the operations waiting the appropriate time for each operation
	for {
		select {
		case <-v.Context.Done():
			return
		case <-ticker.C:
			v.mux.Lock()
			keys := make([]string, 0, len(v.vmssFutureMap))
			for k := range v.vmssFutureMap {
				keys = append(keys, k)
			}

			// print stats
			if time.Since(lastStatssTime) >= PrintStatsCycle {
				lastStatssTime = time.Now()
				log.Info.Printf("OperationManagerStats: Watching %d operations: %v", len(keys), keys)
			}

			v.mux.Unlock()

			// now iterate through the keys
			for _, k := range keys {
				v.mux.Lock()
				op, ok := v.vmssFutureMap[k]
				if !ok {
					v.mux.Unlock()
					continue
				}
				if time.Since(op.LastQuery) < op.WaitDuration {
					v.mux.Unlock()
					continue
				}
				future := op.FutureAPI
				v.mux.Unlock()

				// make blocking call
				log.Info.Printf("get operation call for vmss %s", k)
				done, err := future.DoneWithContext(v.Context, v.Client)

				v.mux.Lock()
				op, ok = v.vmssFutureMap[k]
				if !ok {
					v.mux.Unlock()
					continue
				}
				if time.Since(op.LastQuery) < op.WaitDuration {
					v.mux.Unlock()
					continue
				}
				if done {
					// the operation is complete
					log.Info.Printf("operation complete for vmss %s with status %v", k, future.Status())
					delete(v.vmssFutureMap, k)
				} else {
					if err == nil {
						// check for Retry-After delay, if not present use the client's polling delay
						var ok bool
						delay, ok := future.GetPollingDelay()
						if !ok {
							delay = DEFAULT_OPERATION_POLL_TIME
						}
						op.Attempts = 0
						op.WaitDuration = delay
					} else {
						op.Attempts++
						log.Error.Printf("get operation call for vmss %s, %d attempts with error: %v", k, op.Attempts, err)
						delay := DEFAULT_OPERATION_POLL_TIME * time.Duration(math.Pow(2, float64(op.Attempts)))
						if delay > MAX_OPERATION_POLL_TIME {
							delay = MAX_OPERATION_POLL_TIME
						}
						op.WaitDuration = delay
					}
					op.LastQuery = time.Now()
				}
				v.mux.Unlock()
			}
		}
	}
}

func (v *VmssOperationManager) IsComplete(vmssName string) bool {
	log.Debug.Printf("[vmss.IsComplete")
	defer log.Debug.Printf("vmss.IsComplete]")
	v.mux.Lock()
	defer v.mux.Unlock()

	_, ok := v.vmssFutureMap[vmssName]

	return !ok
}

func (v *VmssOperationManager) AddWatchOperation(vmssName string, futureAPI azure.FutureApi) {
	log.Debug.Printf("[vmss.AddWatchOperation")
	defer log.Debug.Printf("vmss.AddWatchOperation]")
	v.mux.Lock()
	defer v.mux.Unlock()

	delay, ok := futureAPI.GetPollingDelay()
	if !ok {
		delay = DEFAULT_OPERATION_POLL_TIME
	}

	// replace any entries before with the newer entry
	v.vmssFutureMap[vmssName] = &VmssOperation{
		LastQuery:    time.Now(),
		WaitDuration: delay,
		FutureApi:    futureAPI,
	}
}
