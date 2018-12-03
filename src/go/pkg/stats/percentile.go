package stats

// GetPercentileIndex returns the percentile index of the slice
func GetPercentileIndex(percentile float64, arrayLength int) int {
	if percentile < 0.0 {
		return 0
	}
	if percentile > 100.0 {
		return arrayLength - 1
	}

	return int((percentile / 100.0) * float64(arrayLength))
}
