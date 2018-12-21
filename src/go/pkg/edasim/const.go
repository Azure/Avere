package edasim

import "time"

const (
	JobDir   = "/job"
	WorkDir  = "/work"
	StatsDir = "/stats"

	QueueJobReady    = "jobready"
	QueueJobComplete = "jobcomplete"
	QueueJobProcess  = "jobprocess"
	QueueUploader    = "uploader"

	visibilityTimeout = time.Duration(300) * time.Second // 10 minute visibility timeout

	DefaultFileSizeKB              = 384
	DefaultJobCount                = 10
	DefaultJobSubmitterThreadCount = 1

	DefaultOrchestratorThreads = 16
	DefaultWorkStartFiles      = 3
	DefaultJobEndFiles         = 12

	KB = 1024
	MB = KB * KB

	JobReaderLabel              = "JobReader"
	JobWriterLabel              = "JobWriter"
	JobCompleteReaderLabel      = "JobCompleteReader"
	JobCompleteWriterLabel      = "JobCompleteWriter"
	WorkStartFileReaderLabel    = "WorkStartFileReader"
	WorkStartFileWriterLabel    = "WorkStartFileWriter"
	WorkCompleteFileReaderLabel = "WorkCompleteFileReader"
	WorkCompleteFileWriterLabel = "WorkCompleteFileWriter"
)
