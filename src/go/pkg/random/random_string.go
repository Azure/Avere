// Copyright (C) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
package random

import (
	crand "crypto/rand"
	"math/rand"
	"runtime"
	"sync"
	"time"

	"github.com/Azure/Avere/src/go/pkg/log"
)

const letterBytes = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const (
	letterIdxBits   = 6                    // 6 bits to represent a letter index
	letterIdxMask   = 1<<letterIdxBits - 1 // All 1-bits, as many as letterIdxBits
	letterIdxMax    = 63 / letterIdxBits   // # of letter indices fitting in 63 bits
	kb              = 1024
	mb              = kb * kb
	gb              = kb * mb
	randomTableSize = 10 * mb // 10 MB random table
)

var randomTable []byte
var numCPU int

func init() {
	rand.Seed(time.Now().UnixNano())
	randomTable = []byte(RandStringRunesSlow(randomTableSize))
	numCPU = runtime.NumCPU()
}

// RandStringRunesUltraFast returns a random string of size byteCount
func RandStringRunesUltraFast(byteCount int) string {
	if byteCount >= gb {
		return string(RandStringRunesUltraFastBytesParallel(byteCount))
	} else {
		return string(RandStringRunesUltraFastBytes(byteCount))
	}
}

// RandStringRunesUltraFast returns a random string of size byteCount
func RandStringRunesUltraFastBytes(byteCount int) []byte {
	log.Debug.Printf("[RandStringRunesUltraFast(%v)", byteCount)
	defer log.Debug.Printf("RandStringRunesUltraFast(%v)]", byteCount)
	tIndex := rand.Int31n(randomTableSize)
	b := make([]byte, byteCount)
	for i := 0; i < byteCount; i++ {
		b[i] = randomTable[tIndex]
		tIndex = (tIndex + 1) % randomTableSize
	}
	return b
}

// RandStringRunesUltraFast returns a random string of size byteCount
func RandStringRunesUltraFastBytesParallel(byteCount int) []byte {
	log.Debug.Printf("[RandStringRunesUltraFastBytesParallel(%v)", byteCount)
	defer log.Debug.Printf("RandStringRunesUltraFastBytesParallel(%v)]", byteCount)
	b := make([]byte, byteCount)

	syncWaitGroups := sync.WaitGroup{}
	syncWaitGroups.Add(numCPU)
	countPerCPU := byteCount / numCPU

	for i := 0; i < numCPU; i++ {
		startIndex := i * countPerCPU
		stopIndex := countPerCPU
		if i == (numCPU - 1) {
			stopIndex = countPerCPU + (byteCount % numCPU)
		}
		go fillTable(&syncWaitGroups, startIndex, stopIndex, b)
	}
	syncWaitGroups.Wait()
	return b
}

func fillTable(syncWaitGroup *sync.WaitGroup, startIndex int, count int, buffer []byte) {
	log.Debug.Printf("[fillTable(%v,%v)", startIndex, count)
	defer log.Debug.Printf("fillTable(%v,%v)]", startIndex, count)
	defer syncWaitGroup.Done()
	tIndex := rand.Int31n(randomTableSize)
	for i := startIndex; i < (startIndex + count); i++ {
		buffer[i] = randomTable[tIndex]
		tIndex = (tIndex + 1) % randomTableSize
	}
}

// RandStringRunesSlow returns a random string of size byteCount
// implementation derived from https://stackoverflow.com/questions/22892120/how-to-generate-a-random-string-of-a-fixed-length-in-go
func RandStringRunesSlow(byteCount int) string {
	b := make([]byte, byteCount)
	// A rand.Int63() generates 63 random bits, enough for letterIdxMax letters!
	for i, cache, remain := byteCount-1, rand.Int63(), letterIdxMax; i >= 0; {
		if remain == 0 {
			cache, remain = rand.Int63(), letterIdxMax
		}
		if idx := int(cache & letterIdxMask); idx < len(letterBytes) {
			b[i] = letterBytes[idx]
			i--
		}
		cache >>= letterIdxBits
		remain--
	}

	return string(b)
}

// RandStringRunesFast returns a random string of size byteCount
func RandStringRunesFast(byteCount int) string {
	b := make([]byte, byteCount)
	if _, err := crand.Read(b); err != nil {
		log.Error.Printf("RandStringRunesFast failed with error %v", err)
		return RandStringRunesSlow(byteCount)
	}
	return string(b)
}
