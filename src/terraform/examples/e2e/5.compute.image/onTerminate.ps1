$ErrorActionPreference = "Stop"

deadlineworker -shutdown
deadlinecommand -DeleteSlave $(hostname)
