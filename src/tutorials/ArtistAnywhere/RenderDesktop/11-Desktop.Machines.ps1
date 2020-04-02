curl -OutFile "teradici-host-agent.exe" -Uri $args[0]

if ($args.length -gt 1) {
    [System.Environment]::SetEnvironmentVariable("CUEBOT_HOSTS", $args[1], [System.EnvironmentVariableTarget]::Machine)
}

$agentInstall = Start-Process -FilePath "teradici-host-agent.exe" -ArgumentList "/S" -Wait -PassThru
if ($agentInstall.ExitCode -eq 0 -or $agentInstall.ExitCode -eq 1641) {
    # Set host agent license key
}
