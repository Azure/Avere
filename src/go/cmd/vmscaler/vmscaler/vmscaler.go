// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package vmscaler

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/azure"
	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/azure-sdk-for-go/profiles/latest/compute/mgmt/compute"
	"github.com/Azure/azure-storage-queue-go/azqueue"
	"github.com/Azure/go-autorest/autorest"
	"github.com/Azure/go-autorest/autorest/to"
)

const (
	tick                         = time.Duration(10) * time.Millisecond // 10ms
	timeBetweenQueueCheck        = time.Duration(5) * time.Second       // 5 second between checking queues
	timeBetweenVMSSCapacityCheck = time.Duration(1) * time.Minute       // 5 minutes between (we will get throttled if we do > 200 VMSS calls in 5 minutes)
	timeToSeal                   = time.Duration(60) * time.Minute      // 60 minutes to seal a VMSS
	visibilityTimeout            = time.Duration(10) * time.Minute      // 60 minutes to seal a VMSS
	QueueMessageCount            = 1
)

// VMScaler handles all the blob uploads
type VMScaler struct {
	Context                 context.Context
	AzureTenantId           string
	AzureClientId           string
	AzureClientSecret       string
	AzureSubscriptionId     string
	StorageAccountName      string
	StorageAccountKey       string
	StorageAccountQueueName string
	Authorizer              autorest.Authorizer

	TotalNodes int64
	Location   string

	// network configuration values
	VNETResourceGroup string
	VNETName          string
	SubnetName        string

	// VMSS configuration values
	ResourceGroup        string
	SKU                  string
	ImageID              string
	Username             string
	Password             string
	VMsPerVMSS           int64
	SinglePlacementGroup bool
	OverProvision        bool
	Priority             compute.VirtualMachinePriorityTypes
	EvictionPolicy       compute.VirtualMachineEvictionPolicyTypes

	// clients
	rgClient          *azure.ResourceGroup
	vmssClient        *azure.Vmss
	deleteQueueClient *azure.Queue

	// vmss ops manager
	vmssOpManager *azure.VmssOperationManager
}

type Plan struct {
	VmssMap           map[string]compute.VirtualMachineScaleSet
	CurrentCapacity   int64
	IncreasedCapacity int64
	VmssAtCapacity    []string
	VMSSToSeal        []string
	VMSSToIncrease    []string
	VMSSToDelete      []string
	NewVMSSNames      []string
}

func (v *VMScaler) Run(syncWaitGroup *sync.WaitGroup) {
	log.Debug.Printf("[VMScaler.Run")
	log.Debug.Printf("VMScaler.Run]")
	defer syncWaitGroup.Done()

	v.InitializeClients()

	// start the VMSS op manager
	v.vmssOpManager = azure.InitializeVmssOperationManager(v.Context, v.vmssClient.VmssClient.Client)
	syncWaitGroup.Add(1)
	go v.vmssOpManager.Run(syncWaitGroup)

	// only print for debugging purposes
	// log.Debug.Printf("contents of VMScaler %v", v)

	// set the initial target VM Count
	v.getTotalNodes()
	log.Info.Printf("goal state for nodes is %d", v.TotalNodes)

	lastQueueCheckTime := time.Now()
	// check on first loop
	lastVMSSCapacityCheck := time.Now().Add(-timeBetweenVMSSCapacityCheck)
	ticker := time.NewTicker(tick)
	defer ticker.Stop()

	firstRun := true

	// run the infinite loop
	for {
		select {
		case <-v.Context.Done():
			return
		case <-ticker.C:
			if time.Since(lastQueueCheckTime) > timeBetweenQueueCheck {
				lastQueueCheckTime = time.Now()
				if err := v.deleteNodes(); err != nil {
					log.Debug.Printf("error encountered when deleting nodes: %s", err)
				}

				if time.Since(lastVMSSCapacityCheck) > timeBetweenVMSSCapacityCheck {
					// recheck the node count
					v.getTotalNodes()

					lastVMSSCapacityCheck = time.Now()
					log.Info.Printf("update VMSS capacity")

					plan, planErr := v.createPlan(firstRun)
					if planErr != nil {
						log.Error.Printf("error calculating plan: %s", planErr)
						continue
					}

					if executeErr := v.executePlan(plan); executeErr != nil {
						log.Error.Printf("error executing plan %v: %s", plan, executeErr)
					} else if firstRun {
						firstRun = false
						// create a real plan immediately
						lastVMSSCapacityCheck = time.Now().Add(-timeBetweenVMSSCapacityCheck)
					}
				}
			}
		}
	}
}

func (v *VMScaler) InitializeClients() {
	v.rgClient = azure.InitializeResourceGroup(v.Context, v.Authorizer, v.AzureSubscriptionId)
	v.vmssClient = azure.InitializeVmss(v.Context, v.Authorizer, v.AzureSubscriptionId)
	v.deleteQueueClient = azure.InitializeQueue(v.Context, v.StorageAccountName, v.StorageAccountKey, v.StorageAccountQueueName)
}

func (v *VMScaler) getTotalNodes() {
	log.Debug.Printf("[VMScaler.getTotalNodes")
	defer log.Debug.Printf("VMScaler.getTotalNodes]")

	i, err := v.rgClient.GetResourceGroupIntTag(v.ResourceGroup, TOTAL_NODES_TAG_KEY)
	if err != nil {
		log.Error.Printf("unable to read tag, going to set to 0: %s", err)
		v.TotalNodes = int64(0)
		if e := v.setTotalNodes(); e != nil {
			log.Error.Printf("unable to set the nodes to %v: %v", v.TotalNodes, e)
		}
	} else {
		v.TotalNodes = int64(i)
	}
}

func (v *VMScaler) setTotalNodes() error {
	log.Debug.Printf("[VMScaler.setTotalNodes")
	defer log.Debug.Printf("VMScaler.setTotalNodes]")

	_, err := v.rgClient.SetTotalNodesIntTag(v.ResourceGroup, TOTAL_NODES_TAG_KEY, int(v.TotalNodes))
	if err != nil {
		return fmt.Errorf("unable to write tag: %s", err)
	}
	return nil
}

type QueueMessage struct {
	Message  *azqueue.DequeuedMessagesResponse
	Instance string
}

func extractVMSSInstanceCsvMessage(message string) (vmss string, instance string, err error) {
	result := strings.Split(message, ",")
	vmss = ""
	instance = ""
	err = nil
	if len(result) != 2 {
		err = fmt.Errorf("message has incorrect format '%s'", message)
	} else {
		vmss = result[0]
		instance = result[1]
	}
	return
}

func (v *VMScaler) deleteNodes() error {
	log.Debug.Printf("[VMScaler.deleteNodes")
	defer log.Debug.Printf("VMScaler.deleteNodes]")

	vmssInstances := make(map[string][]*QueueMessage)
	instanceCount := 0

	// dequeue all items
	for {
		queueMessage, err := v.deleteQueueClient.Dequeue(QueueMessageCount, visibilityTimeout)
		if err != nil {
			log.Error.Printf("error dequeueing message %v", err)
			break
		}
		if queueMessage.NumMessages() == QueueMessageCount {
			msg := queueMessage.Message(0)
			vmss, instance, err := extractVMSSInstanceCsvMessage(msg.Text)
			if err != nil {
				log.Error.Printf("error dequeueing message %v", err)
				if _, err := v.deleteQueueClient.DeleteMessage(msg.ID, msg.PopReceipt); err != nil {
					log.Error.Printf("error deleting queue message '%s': %v", msg.ID, err)
				}
				continue
			}
			qm := &QueueMessage{
				Message:  queueMessage,
				Instance: instance,
			}
			if _, ok := vmssInstances[vmss]; !ok {
				vmssInstances[vmss] = []*QueueMessage{qm}
			} else {
				vmssInstances[vmss] = append(vmssInstances[vmss], qm)
			}
			instanceCount++
		} else {
			// there are no more messages to process
			break
		}
	}

	if instanceCount == 0 {
		// no work to do, return
		return nil
	}

	// update the capacity tag, but don't go lower than 0
	if v.TotalNodes > 0 {
		nodeCount := v.TotalNodes - int64(instanceCount)
		if nodeCount > 0 {
			v.TotalNodes = nodeCount
		} else {
			v.TotalNodes = 0
		}
		if e := v.setTotalNodes(); e != nil {
			log.Error.Printf("error setting nodes to %v: %v", v.TotalNodes, e)
		}
	}

	// delete the instances
	for k, vi := range vmssInstances {
		instances := []string{}
		for _, i := range vi {
			instances = append(instances, i.Instance)
		}
		var ids compute.VirtualMachineScaleSetVMInstanceRequiredIDs
		ids.InstanceIds = &instances
		forceDelete := false
		future, err := v.vmssClient.VmssClient.DeleteInstances(v.Context, v.ResourceGroup, k, ids, &forceDelete)
		if err != nil {
			log.Error.Printf("error deleting instances for '%s': %v", k, instances)
			continue
		}
		v.vmssOpManager.AddWatchOperation(k, future.FutureAPI)
		// delete the queue messages
		for _, i := range vi {
			msg := i.Message.Message(0)
			if _, err := v.deleteQueueClient.DeleteMessage(msg.ID, msg.PopReceipt); err != nil {
				log.Error.Printf("error deleting queue message '%s': %v", msg.ID, err)
			}
		}
	}

	// dequeue until there are no more items, and delete each item.
	return nil
}

func (v *VMScaler) createPlan(firstRun bool) (*Plan, error) {
	log.Debug.Printf("[VMScaler.createPlan")
	defer log.Debug.Printf("VMScaler.createPlan]")

	var vmssMap map[string]compute.VirtualMachineScaleSet
	vmssMap = make(map[string]compute.VirtualMachineScaleSet)
	var vmssAtCapacity []string
	var vmssToSeal []string
	var vmssToIncrease []string
	var newVMSSNames []string
	var vmssToDelete []string

	currentCapacity := int64(0)
	increasedCapacity := int64(0)

	// read all VMSS resources in the resource group
	vmssList, err := v.vmssClient.ListVMSS(v.ResourceGroup)
	if err != nil {
		return nil, err
	}

	// get the current capacity of all VMSS
	for _, element := range vmssList {
		currentCapacity += *element.Sku.Capacity
	}

	// on first run, we set date on all unsealed VMSS.  This ensures
	// no pre-mature sealing
	if firstRun {
		for _, element := range vmssList {
			if _, ok := element.Tags[SEALED_TAG_KEY]; ok {
				log.Debug.Printf("vmss '%s' is sealed", *element.Name)
				continue
			}
			vmssMap[*element.Name] = element
			vmssAtCapacity = append(vmssAtCapacity, *element.Name)
		}
		plan := &Plan{
			VmssMap:           vmssMap,
			CurrentCapacity:   currentCapacity,
			IncreasedCapacity: increasedCapacity,
			VmssAtCapacity:    vmssAtCapacity,
			VMSSToSeal:        vmssToSeal,
			VMSSToIncrease:    vmssToIncrease,
			VMSSToDelete:      vmssToDelete,
			NewVMSSNames:      newVMSSNames,
		}

		plan.Print(v)

		return plan, nil
	}

	for _, element := range vmssList {
		vmssMap[*element.Name] = element

		if !v.vmssOpManager.IsComplete(*element.Name) {
			log.Info.Printf("skipping vmss '%s', operation still pending", *element.Name)
			continue
		}

		// delete 0 capacity VMSS
		if *element.Sku.Capacity == 0 {
			log.Info.Printf("need to delete %s", *element.Name)
			vmssToDelete = append(vmssToDelete, *element.Name)
			continue
		}

		// skip operations on sealed VMSS
		if _, ok := element.Tags[SEALED_TAG_KEY]; ok {
			log.Debug.Printf("vmss '%s' is sealed", *element.Name)
			continue
		}

		// check VMSS at capacity
		if *element.Sku.Capacity >= v.VMsPerVMSS {
			vmssAtCapacity = append(vmssAtCapacity, *element.Name)
			continue
		}

		// check if VMSS needs to be sealed
		if val, ok := element.Tags[LAST_TIME_AT_CAPACITY_TAG_KEY]; ok {
			var lastTimeAtCapacity time.Time
			if err := lastTimeAtCapacity.UnmarshalText([]byte(*val)); err != nil {
				log.Error.Printf("vmss '%s' has a bad tag", *element.Name)
			} else if time.Since(lastTimeAtCapacity) > timeToSeal {
				vmssToSeal = append(vmssToSeal, *element.Name)
				continue
			}
		}

		// check if VMSS can be increased
		if *element.VirtualMachineScaleSetProperties.ProvisioningState == string(compute.ProvisioningStateSucceeded) {
			if (currentCapacity + increasedCapacity) < v.TotalNodes {
				vmssToIncrease = append(vmssToIncrease, *element.Name)
				increasedCapacity += (v.VMsPerVMSS - *element.Sku.Capacity)
			} else {
				// we have enough nodes, but we should update the timestamp, so we do not seal
				vmssAtCapacity = append(vmssAtCapacity, *element.Name)
			}
			continue
		}
	}

	remainingVMs := v.TotalNodes - (currentCapacity + increasedCapacity)
	if remainingVMs > 0 {
		// creating the new VMSS
		newVmssCount := (remainingVMs / v.VMsPerVMSS)
		if (remainingVMs % v.VMsPerVMSS) > 0 {
			newVmssCount++
		}
		for i := 0; int64(len(newVMSSNames)) < newVmssCount; i++ {
			vmssName := fmt.Sprintf("%s%d", VMSS_PREFIX, i)
			if _, ok := vmssMap[vmssName]; !ok {
				newVMSSNames = append(newVMSSNames, vmssName)
			}
		}
	}

	plan := &Plan{
		VmssMap:           vmssMap,
		CurrentCapacity:   currentCapacity,
		IncreasedCapacity: increasedCapacity,
		VmssAtCapacity:    vmssAtCapacity,
		VMSSToSeal:        vmssToSeal,
		VMSSToIncrease:    vmssToIncrease,
		VMSSToDelete:      vmssToDelete,
		NewVMSSNames:      newVMSSNames,
	}

	plan.Print(v)

	return plan, nil
}

func (v *VMScaler) executePlan(p *Plan) error {
	log.Debug.Printf("[VMScaler.executePlan")
	defer log.Debug.Printf("VMScaler.executePlan]")

	// tag the VMs
	if b, e := time.Now().MarshalText(); e != nil {
		log.Error.Printf("ERROR running time.Now().MarshalText(), bug in Golang?")
	} else {
		for _, element := range p.VmssAtCapacity {
			vmss, ok := p.VmssMap[element]
			if !ok {
				log.Error.Printf("BUG: element %s not found in vmssMap", element)
				continue
			}
			str := string(b)
			if vmss.Tags == nil {
				vmss.Tags = make(map[string]*string)
			}
			vmss.Tags[LAST_TIME_AT_CAPACITY_TAG_KEY] = &str
			future, err := v.vmssClient.Update(v.ResourceGroup, vmss)
			if err != nil {
				log.Error.Printf("error updating '%s': %v, %v", element, err, future)
				continue
			}
			v.vmssOpManager.AddWatchOperation(*vmss.Name, future.FutureAPI)
		}
	}

	// seal the VMs
	if b, e := time.Now().MarshalText(); e != nil {
		log.Error.Printf("ERROR running time.Now().MarshalText(), bug in Golang?")
	} else {
		for _, element := range p.VMSSToSeal {
			vmss, ok := p.VmssMap[element]
			if !ok {
				log.Error.Printf("BUG: element %s not found in vmssMap", element)
				continue
			}
			str := string(b)
			if vmss.Tags == nil {
				vmss.Tags = make(map[string]*string)
			}
			vmss.Tags[SEALED_TAG_KEY] = &str
			future, err := v.vmssClient.Update(v.ResourceGroup, vmss)
			if err != nil {
				log.Error.Printf("error updating '%s': %v, %v", element, err, future)
				continue
			}
			v.vmssOpManager.AddWatchOperation(*vmss.Name, future.FutureAPI)
		}
	}

	// increase the VMs
	if b, e := time.Now().MarshalText(); e != nil {
		log.Error.Printf("ERROR running time.Now().MarshalText(), bug in Golang?")
	} else {
		for _, element := range p.VMSSToIncrease {
			vmss, ok := p.VmssMap[element]
			if !ok {
				log.Error.Printf("BUG: element %s not found in vmssMap", element)
				continue
			}
			str := string(b)
			if vmss.Tags == nil {
				vmss.Tags = make(map[string]*string)
			}
			vmss.Tags[LAST_TIME_AT_CAPACITY_TAG_KEY] = &str
			vmss.Sku.Capacity = &v.VMsPerVMSS
			future, err := v.vmssClient.Update(v.ResourceGroup, vmss)
			if err != nil {
				log.Error.Printf("error updating '%s': %v, %v", element, err, future)
				continue
			}
			v.vmssOpManager.AddWatchOperation(*vmss.Name, future.FutureAPI)
		}
	}

	// delete 0 capacity vmss instances
	for _, element := range p.VMSSToDelete {
		forceDelete := false
		future, err := v.vmssClient.VmssClient.Delete(v.Context, v.ResourceGroup, element, &forceDelete)
		if err != nil {
			log.Error.Printf("error deleting '%s': %v, %v", element, err, future)
			continue
		}
		v.vmssOpManager.AddWatchOperation(element, future.FutureAPI)
	}

	// create the new VMSS
	for _, element := range p.NewVMSSNames {
		vmssModel := v.createNewVmssModel(element)
		future, err := v.vmssClient.Create(v.ResourceGroup, vmssModel)
		if err != nil {
			log.Error.Printf("error updating '%s': %v, %v", element, err, future)
			continue
		}
		v.vmssOpManager.AddWatchOperation(element, future.FutureAPI)
	}

	return nil
}

func (v *VMScaler) createNewVmssModel(vmssName string) compute.VirtualMachineScaleSet {
	// create the new VMSS
	return compute.VirtualMachineScaleSet{
		Name:     to.StringPtr(vmssName),
		Location: to.StringPtr(v.Location),
		Sku: &compute.Sku{
			Name:     to.StringPtr(v.SKU),
			Capacity: to.Int64Ptr(v.VMsPerVMSS),
		},
		VirtualMachineScaleSetProperties: &compute.VirtualMachineScaleSetProperties{
			Overprovision: to.BoolPtr(v.OverProvision),
			UpgradePolicy: &compute.UpgradePolicy{
				Mode: compute.Manual,
			},
			SinglePlacementGroup: to.BoolPtr(v.SinglePlacementGroup),
			VirtualMachineProfile: &compute.VirtualMachineScaleSetVMProfile{
				Priority:       v.Priority,
				EvictionPolicy: v.EvictionPolicy,
				OsProfile: &compute.VirtualMachineScaleSetOSProfile{
					ComputerNamePrefix: to.StringPtr(vmssName),
					AdminUsername:      to.StringPtr(v.Username),
					AdminPassword:      to.StringPtr(v.Password),
				},
				StorageProfile: &compute.VirtualMachineScaleSetStorageProfile{
					ImageReference: &compute.ImageReference{
						ID: to.StringPtr(v.ImageID),
					},
				},
				NetworkProfile: &compute.VirtualMachineScaleSetNetworkProfile{
					NetworkInterfaceConfigurations: &[]compute.VirtualMachineScaleSetNetworkConfiguration{
						{
							Name: to.StringPtr(vmssName),
							VirtualMachineScaleSetNetworkConfigurationProperties: &compute.VirtualMachineScaleSetNetworkConfigurationProperties{
								Primary:                     to.BoolPtr(true),
								EnableAcceleratedNetworking: to.BoolPtr(true),
								EnableIPForwarding:          to.BoolPtr(false),
								IPConfigurations: &[]compute.VirtualMachineScaleSetIPConfiguration{
									{
										Name: to.StringPtr(vmssName),
										VirtualMachineScaleSetIPConfigurationProperties: &compute.VirtualMachineScaleSetIPConfigurationProperties{
											Subnet: &compute.APIEntityReference{
												ID: to.StringPtr(azure.GetSubnetId(v.AzureSubscriptionId, v.VNETResourceGroup, v.VNETName, v.SubnetName)),
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}
}

func (p *Plan) Print(v *VMScaler) {
	log.Info.Printf("PLAN: Capacity - current: %d, increased: %d, target %d ", p.CurrentCapacity, p.IncreasedCapacity, v.TotalNodes)
	log.Info.Printf("PLAN: VMSS - counts existing: %d, new: %d", len(p.VmssMap), len(p.NewVMSSNames))
	log.Info.Printf("PLAN: VMSS capacity counts - atCapacity %d, toIncrease %d, toSeal %d, sealed %d", len(p.VmssAtCapacity), len(p.VMSSToIncrease), len(p.VMSSToSeal), (len(p.VmssMap) - (len(p.VmssAtCapacity) + len(p.VMSSToIncrease) + len(p.VMSSToSeal))))
	log.Debug.Printf("PLAN: VmssAtCapacity %v", p.VmssAtCapacity)
	log.Debug.Printf("PLAN: VMSSToSeal %v", p.VMSSToSeal)
	log.Debug.Printf("PLAN: VMSSToIncrease %v", p.VMSSToIncrease)
	log.Debug.Printf("PLAN: VMSSToDelete %v", p.VMSSToDelete)
	log.Debug.Printf("PLAN: NewVMSSNames %v", p.NewVMSSNames)
}
