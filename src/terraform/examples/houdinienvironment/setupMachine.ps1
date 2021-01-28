<#
    .SYNOPSIS
        Configure Windows 10 Workstation with Domain Join.

    .DESCRIPTION
        Configure Windows 10 Workstation with Domain Join.

        Example command line: .\setupMachine.ps1 -RenameVMPrefix 'eus' -ADDomain 'rendering.com' -OUPath 'OU=anthony,DC=rendering,DC=com' -DomainUser 'azureuser' -DomainPassword 'ReplacePassword1$' -RDPPort 3389
#>
[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [string]
    $RenameVMPrefix = "",
    
    [string]
    $ADDomain = "",

    [string]
    $OUPath = "",

    [string]
    $DomainUser = "",

    [string]
    $DomainPassword = "",

    [int]
    $RDPPort = 3389

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

# technique from here https://stackoverflow.com/questions/45470999/powershell-try-catch-and-retry
function Retry-Command {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position=1, Mandatory=$false)]
        [int]$Maximum = 120,

        [Parameter(Position=2, Mandatory=$false)]
        [int]$Delay = 5000
    )

    Begin {
        $cnt = 0
    }

    Process {
        do {
            $cnt++
            try {
                $ScriptBlock.Invoke()
                return
            } catch {
                Write-Error $_.Exception.InnerException.Message -ErrorAction Continue
                Start-Sleep -Milliseconds $Delay
            }
        } while ($cnt -lt $Maximum)

        # Throw an error after $Maximum unsuccessful invocations. Doesn't need
        # a condition, since the function returns upon successful invocation.
        throw 'Execution failed.'
    }
}

function
Disable-PrivacyExperience
{
    $TSPath = 'HKLM:\Software\Policies\Microsoft\Windows\OOBE'
    if (Test-Path $TSPath)
    {
        Write-Log "Updating Property $TSPath"
        Set-ItemProperty -Path $TSPath -name DisablePrivacyExperience -Value 1 -Type DWord
    }
    else
    {
        Write-Log "Creating Property $TSPath"
        New-Item -Path $TSPath
        New-ItemProperty -Path $TSPath -Name DisablePrivacyExperience -Value 1 -Type DWord
    }
}

function 
Update-RDPPort
{
    $TSPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    $RDPTCPpath = $TSPath + '\Winstations\RDP-Tcp'
    Set-ItemProperty -Path $TSPath -name 'fDenyTSConnections' -Value 0

    # RDP port
    $portNumber = (Get-ItemProperty -Path $RDPTCPpath -Name 'PortNumber').PortNumber
    Write-Host Get RDP PortNumber: $portNumber
    if (!($portNumber -eq $RDPPort))
    {
        Write-Host Setting RDP PortNumber to $RDPPort
        Set-ItemProperty -Path $RDPTCPpath -name 'PortNumber' -Value $RDPPort
        Restart-Service TermService -force
    }

    #Setup firewall rules
    if ($RDPPort -eq 3389)
    {
        netsh advfirewall firewall set rule group="remote desktop" new Enable=Yes
    } 
    else
    {
        $systemroot = get-content env:systemroot
        netsh advfirewall firewall add rule name="Remote Desktop - Custom Port" dir=in program=$systemroot\system32\svchost.exe service=termservice action=allow protocol=TCP localport=$RDPPort enable=yes
    }
}

function
Rename-VM
{
    $newName = ""
    if ($RenameVMPrefix -ne "")
    {
        $getip = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -ne "Disconnected"}).IPv4Address.IPAddress
        $ip2 = $getip.split('.')
        $newName = $RenameVMPrefix + $ip2[2] + "-" + $ip2[3]
        Rename-Computer -NewName $newName -Force
    }
    return $newName
}

function
Remove-DomainNameIfExists($computerName)
{
    if ($DomainUser -ne "" -And $DomainPassword -ne "" -And $ADDomain -ne "" )
    {
        # remove domain if it already exists
        $DomainInfo    = New-Object DirectoryServices.DirectoryEntry("LDAP://$ADDomain", $DomainUser, $DomainPassword)
        $Search        = New-Object DirectoryServices.DirectorySearcher($DomainInfo)
        $Search.Filter = "(samAccountName=$($computerName)$)"

        Retry-Command -ScriptBlock {
            if ($Comp = $Search.FindOne()) {
                Write-Log "removing existing entry $computerName"
                $Comp.GetDirectoryEntry().DeleteTree()
                Start-Sleep -Seconds 5
            }
        }
    }
    else
    {
        Write-Log "Unable to remove domain name, one of domain, user, password is empty"
    }
}

function
DomainJoin-VM($originalName, $newName)
{
    if ($DomainUser -ne "" -And $DomainPassword -ne "" -And $ADDomain -ne "" )
    {
        $securepw = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
        # during automation, you must use FQDN: https://stackoverflow.com/questions/32076717/failed-to-join-domain-with-automated-powershell-script-unable-to-update-pass
        $joinCred = New-Object System.Management.Automation.PSCredential("$DomainUser@$ADDomain", $securepw)

        Retry-Command -ScriptBlock {
            # Try to remove existing names in the following two cases:
            # 1. Remove the existing names if they already exist because of a previous scale-up
            # 2. It is possible Add-Computer hits 'The directory service is busy' 
            #    so we have to remove the name before retrying Add-Computer
            Remove-DomainNameIfExists -computerName $originalName
            if ($newName -ne "")
            {
                Remove-DomainNameIfExists -computerName $newName
            }
            # add computer to domain
            if ($newName -ne "")
            {
                if ($OUPath -ne "")
                {
                    Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force -ErrorAction Stop -NewName $newName -OUPath $OUPath
                }
                else
                {
                    Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force -ErrorAction Stop -NewName $newName
                }
            }
            else
            {
                if ($OUPath -ne "")
                {
                    Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force -ErrorAction Stop -OUPath $OUPath
                }
                else
                {
                    Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force -ErrorAction Stop
                }
            }
        }
    }
    else
    {
        Write-Log "Unable to join domain, one of domain, user, password is empty"
    }
}

try
{
    # Set to false for debugging.  This will output the start script to
    # c:\AzureData\CustomDataSetupScript.log, and then you can RDP
    # to the windows machine, and run the script manually to watch
    # the output.
    if ($true)
    {
        Disable-PrivacyExperience

        Update-RDPPort

        # install NSSM to disable the NICS
        Get-NSSM
        $azureBasePath = "C:\AzureData"
        $configureNicServiceFile = "$azureBasePath\ConfigureNicServiceInfinite.ps1"
        Write-ConfigureNicServiceFile -NicServiceFile $configureNicServiceFile
        Create-NSSMService -NicServiceFile $configureNicServiceFile

        $originalName = $env:computername
        Write-Log "Renaming VM from $originalName"
        $newName = Rename-VM

        Write-Log "Joining Domain with rename to '$newName'"
        DomainJoin-VM -originalName $originalName -newName $newName

        # shutdown after joining VM
        shutdown /r /t 30

        Write-Log "Complete"
    }
    else
    {
        # keep for debugging purposes
        Write-Log "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
        Write-Log ".\CustomDataSetupScript.ps1 -RenameVMPrefix '$RenameVMPrefix' -ADDomain $ADDomain -OUPath '$OUPath' -DomainUser '$DomainUser' -DomainPassword '$DomainPassword' -RDPPort $RDPPort "
    }
}
catch
{
    Write-Error $_
}