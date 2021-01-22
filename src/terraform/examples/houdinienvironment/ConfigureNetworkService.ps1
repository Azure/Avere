<#
    .SYNOPSIS
        Remove the RDMA / Infiniband NICs so they don't collide with on-prem networks.

    .DESCRIPTION
        This will install the NSSM service, that will remove the RDMA / Infiniband NICs so they don't collide with on-prem networks.
        Disabling NICs is not good enough since a stop deallocate / start will bring back the NICs with new MAC addresses.  This 
        service will stop those additional NICs.

        Example command line if there is access to internet: 
            powershell -ExecutionPolicy Bypass -NoProfile -File .\ConfigureNetworkService.ps1

        Example command line if there is no access to network, but access to SMB share: 
            powershell -ExecutionPolicy Bypass -NoProfile -File .\ConfigureNetworkService.ps1 -NSSMPath \\software\software\nssm\nssm-2.24.zip
#>
[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $NSSMPath = "https://nssm.cc/release/nssm-2.24.zip"
)

filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message)
{
    $msg = $message | Timestamp
    Write-Output $msg
    [Console]::Out.Flush() 
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
Copy-File
{
    [CmdletBinding()]
    param(
        [string]
        $SourcePath,

        [string]
        $DestinationPath
    )

    if ($SourcePath -eq $DestinationPath)
    {
        return
    }

    if (Test-Path $SourcePath)
    {
        Copy-Item -Path $SourcePath -Destination $DestinationPath
    }
    elseif (($SourcePath -as [System.URI]).AbsoluteURI -ne $null)
    {
        Write-Log "Downloading $SourcePath..."
        DownloadFileOverHttp -Url $SourcePath -DestinationPath $DestinationPath
    }
    else
    {
        throw "Cannot copy from $SourcePath"
    }
}

function
Get-NSSM
{
    if (Test-Path "$($env:SystemRoot)\System32\nssm.exe")
    {
        Write-Log "NSSM is already installed"
    } else {
        Write-Log "This script uses a third party tool: NSSM. For more information, see https://nssm.cc/usage"
        
        Write-Log "Clean up previous artifacts..."
        $nssmZip = "$($env:temp)\nssm-2.24.zip"
        $nssmExtractDir = "$($env:temp)\nssm"
        Remove-Item "$nssmZip" -Recurse -ErrorAction Ignore
        Remove-Item "$nssmExtractDir" -Recurse -ErrorAction Ignore
        
        Write-Log "Copy NSSM from source..."
        Copy-File -SourcePath $NSSMPath -DestinationPath $nssmZip
                
        Write-Log "Expand NSSM and copy ..."
        $tempDirectory = New-Item -ItemType Directory -Force -Path "$nssmExtractDir"
        Expand-Archive -Path $nssmZip -DestinationPath $tempDirectory.FullName
        Remove-Item "$nssmZip" -Recurse -ErrorAction Ignore
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
    [Console]::Out.Flush()
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
        # sleep 60 seconds, before checking again
        Start-Sleep -Milliseconds 60000
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
    $ConfigureNicServiceName = "DisableInfinibandNics"
    $existingService = Get-Service | Where-Object {$_.Name -eq "$ConfigureNicServiceName"}
    if ($existingService.Length -eq 0)
    {
        #Set-ExecutionPolicy -ExecutionPolicy Unrestricted
        $Binary = (Get-Command Powershell).Source
        $Arguments = '-ExecutionPolicy Bypass -NoProfile -File "' + $NicServiceFile + '"'
        $azureBasePath = "C:\AzureData"
        $configureNicServiceLog = "$azureBasePath\nicservice.log"
        New-Item -ItemType Directory -Force -Path $azureBasePath
        Write-Log "Configuring NSSM for ConfigureNIC service..."
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