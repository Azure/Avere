param (
    [string] $fileSystemMounts,
    [string] $openCueRenderManagerHost,
    [string] $teradiciHostAgentFileUrl,
    [string] $teradiciHostAgentFileName,
    [string] $teradiciHostAgentLicenseKey
)

Set-Location -Path 'C:\Users\Public\Downloads'

foreach ($fileSystemMount in $fileSystemMounts.Split(';')) {
    $mountParameters = $fileSystemMount.Split(' ')
    $mountRoot = '\\' + $mountParameters[0].Replace(':', '').Replace('/', '\')
    $mountDrive = $mountParameters[-2]
    New-PSDrive -Name $mountDrive -PSProvider FileSystem -Root $mountRoot -Scope Global -Persist
}

[System.Environment]::SetEnvironmentVariable('CUEBOT_HOSTS', $openCueRenderManagerHost, [System.EnvironmentVariableTarget]::Machine)

if ($teradiciHostAgentLicenseKey -ne '') {
    Invoke-WebRequest -Uri $teradiciHostAgentFileUrl -OutFile $teradiciHostAgentFileName
    $agentInstall = Start-Process -FilePath $teradiciHostAgentFileName -ArgumentList '/S /NoPostReboot' -Wait -PassThru
    if ($agentInstall.ExitCode -eq 0 -or $agentInstall.ExitCode -eq 1641) {
        Set-Location -Path 'C:\Program Files\Teradici\PCoIP Agent\'
        & .\pcoip-register-host.ps1 -RegistrationCode $teradiciHostAgentLicenseKey
        & .\pcoip-validate-license.ps1
        Restart-Service -Name 'PCoIPAgent'
    }
}
