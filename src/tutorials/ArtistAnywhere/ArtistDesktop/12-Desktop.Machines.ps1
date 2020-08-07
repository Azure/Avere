param (
    [string] $fileSystemMounts,
    [string] $renderManagerHost,
    [string] $teradiciAgentFileUrl,
    [string] $teradiciAgentFileName,
    [string] $teradiciAgentLicenseKey
)

Set-Location -Path '/Users/Public/Downloads'

foreach ($fileSystemMount in $fileSystemMounts.Split(';')) {
    $mountParameters = $fileSystemMount.Split(' ')
    $mountRoot = '\\' + $mountParameters[0].Replace(':', '').Replace('/', '\')
    $mountDrive = $mountParameters[-1]
    New-PSDrive -Name $mountDrive -PSProvider FileSystem -Root $mountRoot -Scope Global -Persist
}

[System.Environment]::SetEnvironmentVariable('CUEBOT_HOSTS', $renderManagerHost, [System.EnvironmentVariableTarget]::Machine)

if ($teradiciAgentLicenseKey -ne '') {
    Invoke-WebRequest -Uri $teradiciAgentFileUrl -OutFile $teradiciAgentFileName
    $agentInstall = Start-Process -FilePath $teradiciAgentFileName -ArgumentList '/S /NoPostReboot' -Wait -PassThru
    if ($agentInstall.ExitCode -eq 0 -or $agentInstall.ExitCode -eq 1641) {
        Set-Location -Path 'C:\Program Files\Teradici\PCoIP Agent\'
        & .\pcoip-register-host.ps1 -RegistrationCode $teradiciAgentLicenseKey
        & .\pcoip-validate-license.ps1
        Restart-Service -Name 'PCoIPAgent'
    }
}
