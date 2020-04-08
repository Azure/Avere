param (
    [string] $teradiciHostAgentUrl,
    [string] $teradiciHostAgentKey,
    [string] $teradiciSessionViewerUrl,
    [string] $openCueRenderManagerHost
)

curl -OutFile 'teradici-host-agent.exe' -Uri $teradiciHostAgentUrl
curl -OutFile 'teradici-session-viewer.exe' -Uri $teradiciSessionViewerUrl
$agentInstall = Start-Process -FilePath 'teradici-host-agent.exe' -ArgumentList '/S /NoPostReboot' -Wait -PassThru
if ($agentInstall.ExitCode -eq 0 -or $agentInstall.ExitCode -eq 1641) {
    if ($teradiciAgentKey -ne '') {
        Set-Location -Path 'C:\Program Files\Teradici\PCoIP Agent\'
        & .\pcoip-register-host.ps1 -RegistrationCode $teradiciHostAgentKey
        & .\pcoip-validate-license.ps1
    }
    Restart-Service -Name 'PCoIPAgent'
}

[System.Environment]::SetEnvironmentVariable('CUEBOT_HOSTS', $openCueRenderManagerHost, [System.EnvironmentVariableTarget]::Machine)
