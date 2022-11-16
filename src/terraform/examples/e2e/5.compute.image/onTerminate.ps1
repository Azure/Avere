$ErrorActionPreference = "Stop"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

deadlineworker -shutdown
deadlinecommand -DeleteSlave $(hostname)