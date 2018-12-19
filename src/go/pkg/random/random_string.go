package random

import (
	"math/rand"
	"time"
)

const letterBytes = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const (
	letterIdxBits   = 6                    // 6 bits to represent a letter index
	letterIdxMask   = 1<<letterIdxBits - 1 // All 1-bits, as many as letterIdxBits
	letterIdxMax    = 63 / letterIdxBits   // # of letter indices fitting in 63 bits
	kb              = 1024
	mb              = kb * kb
	randomTableSize = 10 * mb // 10 MB random table
)

var randomTable []byte

func init() {
	rand.Seed(time.Now().UnixNano())
	randomTable = []byte(RandStringRunesSlow(randomTableSize))
}

// RandStringRunesUltraFast returns a random string of size byteCount
func RandStringRunesUltraFast(kbCount int) string {
	tIndex := rand.Int31n(randomTableSize)
	byteCount := kbCount * kb
	b := make([]byte, byteCount)
	for i := 0; i < byteCount; i++ {
		b[i] = randomTable[tIndex]
		tIndex = (tIndex + 1) % randomTableSize
	}
	return string(b)
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
