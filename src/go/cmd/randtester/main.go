// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package main

import (
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
	"github.com/Azure/Avere/src/go/pkg/random"
)

func main() {
	now := time.Now()
	defer func() {
		log.Info.Printf("duration %v", time.Now().Sub(now))
	}()
	numberOfThreads := 20
	numberOfRand := 10
	syncWaitGroup := sync.WaitGroup{}

	for i := 0; i < numberOfThreads; i++ {
		syncWaitGroup.Add(1)
		go func() {
			defer syncWaitGroup.Done()
			for j := 0; j < numberOfRand; j++ {
				//_ = random.RandStringRunesSlow(8192 * 1024)
				_ = random.RandStringRunesUltraFast(8192)
			}
		}()
	}

	log.Info.Printf("Waiting for all processes to finish")
	syncWaitGroup.Wait()

	log.Info.Printf("%s", random.RandStringRunesUltraFast(1))

	log.Info.Printf("finished")
}
