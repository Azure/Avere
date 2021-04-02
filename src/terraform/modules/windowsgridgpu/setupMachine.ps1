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
    $ADDomain = "",

    [string]
    $OUPath = "",

    [string]
    $DomainUser = "",

    [string]
    $DomainPassword = "",

    [string]
    $TeradiciLicenseKey = "",

    [string]
    [ValidateNotNullOrEmpty()]
    $GridUrl = "",

    [string]
    [ValidateNotNullOrEmpty()]
    $TeradiciPcoipAgentUrl = ""
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
DomainJoin-VM
{
    if ($DomainUser -ne "" -And $DomainPassword -ne "" -And $ADDomain -ne "" )
    {
        $securepw = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
        # during automation, you must use FQDN: https://stackoverflow.com/questions/32076717/failed-to-join-domain-with-automated-powershell-script-unable-to-update-pass
        $joinCred = New-Object System.Management.Automation.PSCredential("$DomainUser@$ADDomain", $securepw)

        Retry-Command -ScriptBlock {
            # Try to remove existing name
            Remove-DomainNameIfExists -computerName $env:computername
            # add computer to domain
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
    else
    {
        Write-Log "Unable to join domain, one of domain, user, password is empty"
    }
}

function
Configure-Grid
{
    if ($GridUrl -ne "")
    {
        $fileName = "$($env:temp)\gridwin10.exe"
        Remove-Item "$fileName" -Recurse -ErrorAction Ignore
            
        Write-Log "Copy grid file from source..."
        Copy-File -SourcePath $GridUrl -DestinationPath $fileName

        Start-Process -FilePath $fileName -ArgumentList "/s /noreboot" -Wait
    }
}

function
Configure-Teradici
{
    if ($TeradiciPcoipAgentUrl -ne "")
    {
        $fileName = "$($env:temp)\pcoip.exe"
        Remove-Item "$fileName" -Recurse -ErrorAction Ignore
            
        Write-Log "Copy pcoip file from source..."
        Copy-File -SourcePath $TeradiciPcoipAgentUrl -DestinationPath $fileName

        Start-Process -FilePath $fileName -ArgumentList "/S /NoPostReboot /Force" -Wait
    }

    if ($TeradiciLicenseKey -ne "")
    {
        $path = "c:\Program Files\Teradici\PCoIP Agent\pcoip-register-host.ps1"
        $path = $path -replace ' ', '` '
        Invoke-Expression("$path -RegistrationCode $TeradiciLicenseKey")
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

        Write-Log "configure Grid"
        Configure-Grid

        Write-Log  "configure Teradici"
        Configure-Teradici

        Write-Log "Joining Domain"
        DomainJoin-VM

        # shutdown after joining VM
        shutdown /r /t 30

        Write-Log "Complete"
    }
    else
    {
        # keep for debugging purposes
        Write-Log "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
        Write-Log ".\CustomDataSetupScript.ps1 -ADDomain $ADDomain -OUPath '$OUPath' -DomainUser '$DomainUser' -DomainPassword '$DomainPassword' -TeradiciLicenseKey '$TeradiciLicenseKey' -GridUrl '$GridUrl' -TeradiciPcoipAgentUrl '$TeradiciPcoipAgentUrl' "
    }
}
catch
{
    Write-Error $_
}
