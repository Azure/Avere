param (
    [string] $teradiciHostAgentLicenseKey,
    [string] $teradiciHostAgentFilePath,
    [string] $openCueRenderManagerHost,
    [string] $fileSystemMounts
)

if ($teradiciHostAgentLicenseKey -ne '') {
    $agentInstall = Start-Process -FilePath $teradiciHostAgentFilePath -ArgumentList '/S /NoPostReboot' -Wait -PassThru
    if ($agentInstall.ExitCode -eq 0 -or $agentInstall.ExitCode -eq 1641) {
        Set-Location -Path 'C:\Program Files\Teradici\PCoIP Agent\'
        & .\pcoip-register-host.ps1 -RegistrationCode $teradiciHostAgentLicenseKey
        & .\pcoip-validate-license.ps1
        Restart-Service -Name 'PCoIPAgent'
    }
}

[System.Environment]::SetEnvironmentVariable('CUEBOT_HOSTS', $openCueRenderManagerHost, [System.EnvironmentVariableTarget]::Machine)

foreach ($fileSystemMount in $fileSystemMounts.Split(';')) {
    $mountParameters = $fileSystemMount.Split(' ')
    $mountRoot = "\\" + $mountParameters[0]
    $mountDrive = $mountParameters[-1]
    New-PSDrive -Name $mountDrive -PSProvider FileSystem -Root $mountRoot -Scope Global -Persist
}
