package edasim

import (
	"context"
)

type key int

const statsChannelsKey key = 0

// StatsChannels defines the stats channels that counts queue stats
type StatsChannels struct {
	ChJobProcessed          chan struct{}
	ChProcessedFilesWritten chan struct{}
	ChJobCompleted          chan struct{}
	ChUpload                chan struct{}
	ChError                 chan struct{}
}

// SetStatsChannel adds the stats channel to the context
func SetStatsChannel(ctx context.Context) context.Context {
	return context.WithValue(ctx, statsChannelsKey, InitializeStatsChannels())
}

// GetStatsChannel gets the stats channel from the context
func GetStatsChannel(ctx context.Context) *StatsChannels {
	return ctx.Value(statsChannelsKey).(*StatsChannels)
}

// InitializeStatsChannels initializes the stats channels
func InitializeStatsChannels() *StatsChannels {
	return &StatsChannels{
		ChJobProcessed:          make(chan struct{}),
		ChProcessedFilesWritten: make(chan struct{}),
		ChJobCompleted:          make(chan struct{}),
		ChUpload:                make(chan struct{}),
		ChError:                 make(chan struct{}),
	}
}

// JobProcessed signals a job was processed
func (s *StatsChannels) JobProcessed() {
	s.ChJobProcessed <- struct{}{}
}

// ProcessedFilesWritten signals the worker start files were written
func (s *StatsChannels) ProcessedFilesWritten() {
	s.ChProcessedFilesWritten <- struct{}{}
}

// JobCompleted signals the job was completed and the file was written
func (s *StatsChannels) JobCompleted() {
	s.ChJobCompleted <- struct{}{}
}

// Upload signals that an upload was queued
func (s *StatsChannels) Upload() {
	s.ChUpload <- struct{}{}
}

// Error signals that an error was encountered
func (s *StatsChannels) Error() {
	s.ChError <- struct{}{}
}
