param (
    [string] $fileSystemMounts,
    [string] $openCueRenderManagerHost,
    [string] $teradiciHostAgentFilePath,
    [string] $teradiciHostAgentLicenseKey,
    [string] $teradiciSessionViewerFilePath
)

foreach ($fileSystemMount in $fileSystemMounts.Split('|')) {
    $mountParameters = $fileSystemMount.Split(' ')
    $mountRoot = "\\" + $mountParameters[0]
    $mountDrive = $mountParameters[-1]
    New-PSDrive -Name $mountDrive -PSProvider FileSystem -Root $mountRoot -Scope Global -Persist
}

$teradiciHostAgentInstallFileName = 'teradici-host-agent.exe'
Copy-Item -Path $teradiciHostAgentFilePath -Destination $teradiciHostAgentInstallFileName
Copy-Item -Path $teradiciSessionViewerFilePath -Destination 'teradici-session-viewer.exe'

$agentInstall = Start-Process -FilePath $teradiciHostAgentInstallFileName -ArgumentList '/S /NoPostReboot' -Wait -PassThru
if ($agentInstall.ExitCode -eq 0 -or $agentInstall.ExitCode -eq 1641) {
    if ($teradiciHostAgentLicenseKey -ne '') {
        Set-Location -Path 'C:\Program Files\Teradici\PCoIP Agent\'
        & .\pcoip-register-host.ps1 -RegistrationCode $teradiciHostAgentLicenseKey
        & .\pcoip-validate-license.ps1
    }
    Restart-Service -Name 'PCoIPAgent'
}

[System.Environment]::SetEnvironmentVariable('CUEBOT_HOSTS', $openCueRenderManagerHost, [System.EnvironmentVariableTarget]::Machine)
