package edasim

const (
	QueueJobReady    = "jobready"
	QueueJobComplete = "jobcomplete"
	QueueJobProcess  = "jobprocess"
	QueueUploader    = "uploader"

	DefaultFileSizeKB = 384
	DefaultJobCount   = 10
	DefaultUserCount  = 1

	DefaultOrchestratorThreads = 16
	DefaultJobStartFiles       = 3
	DefaultJobEndFiles         = 12

	KB = 1024
	MB = KB * KB
)
