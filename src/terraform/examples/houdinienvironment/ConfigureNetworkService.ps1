<#
    .SYNOPSIS
        Configure Windows 10 Workstation with Domain Join.

    .DESCRIPTION
        Configure Windows 10 Workstation with Domain Join.

        Example command line: .\setupMachine.ps1 -RenameVMPrefix 'eus' -ADDomain 'rendering.com' -OUPath 'OU=anthony,DC=rendering,DC=com' -DomainUser 'azureuser' -DomainPassword 'ReplacePassword1$' -RDPPort 3389
#>
[CmdletBinding(DefaultParameterSetName="Standard")]
param()

filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message)
{
    $msg = $message | Timestamp
    Write-Output $msg
}

function
DownloadFileOverHttp($Url, $DestinationPath)
{
     $secureProtocols = @()
     $insecureProtocols = @([System.Net.SecurityProtocolType]::SystemDefault, [System.Net.SecurityProtocolType]::Ssl3)

     foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType]))
     {
         if ($insecureProtocols -notcontains $protocol)
         {
             $secureProtocols += $protocol
         }
     }
     [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols

    # make Invoke-WebRequest go fast: https://stackoverflow.com/questions/14202054/why-is-this-powershell-code-invoke-webrequest-getelementsbytagname-so-incred
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $Url -UseBasicParsing -OutFile $DestinationPath -Verbose
    Write-Log "$DestinationPath updated"
}

function
Get-NSSM
{
    if (Test-Path "$($env:SystemRoot)\System32\nssm.exe")
    {
        Write-Log "NSSM is already installed"
    } else {
        Write-Log "This script uses a third party tool: NSSM. For more information, see https://nssm.cc/usage"
        Write-Log "Downloading NSSM..."
        $nssmUri = "https://nssm.cc/release/nssm-2.24.zip"
        $nssmZip = "$($env:temp)\$(Split-Path $nssmUri -Leaf)"

        Write-Verbose "Creating working directory..."
        $tempDirectory = New-Item -ItemType Directory -Force -Path "$($env:temp)\nssm"

        DownloadFileOverHttp -Url $nssmUri -DestinationPath $nssmZip
        Expand-Archive -Path $nssmZip -DestinationPath $tempDirectory.FullName
        Remove-Item $nssmZip
        Copy-Item -Path "$($tempDirectory.FullName)\nssm-2.24\win64\nssm.exe" -Destination "$($env:SystemRoot)\System32"
    }
}

function
Write-ConfigureNicServiceFile($NicServiceFile)
{
    $fileContents = @"
[CmdletBinding(DefaultParameterSetName="Standard")]
param()

filter Timestamp {"`$(Get-Date -Format o): `$_"}

function
Write-Log(`$message)
{
    `$msg = `$message | Timestamp
    Write-Output `$msg
}

function 
Disable-NonGateway-NICs
{
    `$nics = Get-NetIPConfiguration |Where-Object {`$_.IPv4DefaultGateway -eq `$null}
    foreach (`$nic in `$nics)
    {
        `$nicName = `$nic.InterfaceAlias
        Write-Log "disabling nic `$nicName"
        Disable-NetAdapter -Name `$nicName -Confirm:`$False
    }
}

try
{
    while(`$true) {
        # Write-Log "confirm nic disabled `$nicName"
        Disable-NonGateway-NICs
        # sleep 10 minutes, before checking again
        Start-Sleep -Milliseconds 600000
    }
    
}
catch
{
    Write-Error `$_
}

"@
    $fileContents | Out-File -encoding ASCII -filepath "$NicServiceFile"
}

function
Create-NSSMService($NicServiceFile)
{
    #Set-ExecutionPolicy -ExecutionPolicy Unrestricted
    $Binary = (Get-Command Powershell).Source
    $Arguments = '-ExecutionPolicy Bypass -NoProfile -File "' + $NicServiceFile + '"'
    $azureBasePath = "C:\AzureData"
    $configureNicServiceLog = "$azureBasePath\nicservice.log"
    New-Item -ItemType Directory -Force -Path $azureBasePath
    Write-Log "Configuring NSSM for ConfigureNIC service..."
    $ConfigureNicServiceName = "DisableInfinibandNics"
    Start-Process -Wait "nssm" -ArgumentList "install $ConfigureNicServiceName $Binary $Arguments"
    Start-Process -Wait "nssm" -ArgumentList "set $ConfigureNicServiceName DisplayName Disable Infiniband NICs"
    Start-Process -Wait "nssm" -ArgumentList "set $ConfigureNicServiceName Description Disable Infiniband NICs because they collide with on-prem networks"
    # Pipe output to daemon.log
    Start-Process -Wait "nssm" -ArgumentList "set $ConfigureNicServiceName AppStderr $configureNicServiceLog"
    Start-Process -Wait "nssm" -ArgumentList "set $ConfigureNicServiceName AppStdout $configureNicServiceLog"
    # Allow 10 seconds for graceful shutdown before process is terminated
    Start-Process -Wait "nssm" -ArgumentList "set $ConfigureNicServiceName AppStopMethodConsole 10000"

    Start-Service -Name $ConfigureNicServiceName
}

try
{
    Get-NSSM
    $azureBasePath = "C:\AzureData"
    New-Item -ItemType Directory -Force -Path $azureBasePath
    $configureNicServiceFile = "$azureBasePath\ConfigureNicServiceInfinite.ps1"
    Write-ConfigureNicServiceFile -NicServiceFile $configureNicServiceFile
    Create-NSSMService -NicServiceFile $configureNicServiceFile

    Write-Log "Complete"
}
catch
{
    Write-Error $_
}