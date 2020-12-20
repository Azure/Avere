<#
    .SYNOPSIS
        Configure Windows 10 Workstation with Media.

    .DESCRIPTION
        Configure Windows 10 Workstation with Media.

        Example command line: .\startupAvere azureuser 172.16.0.15 172.16.0.22 msazure
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
Disable-NonGateway-NICs
{
    $nics = Get-NetIPConfiguration |Where-Object {$_.IPv4DefaultGateway -eq $null}
    foreach ($nic in $nics)
    {
        $nicName = $nic.InterfaceAlias
        Write-Log "disabling nic $nicName"
        Disable-NetAdapter -Name $nicName -Confirm:$False
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
Remove-DomainNameIfExists
{
    if ($DomainUser -ne "" -And $DomainPassword -ne "" -And $ADDomain -ne "" )
    {
        # remove domain if it already exists
        $computerName  = if ($newName) { $newName } else { $env:computername }
        $DomainInfo    = New-Object DirectoryServices.DirectoryEntry("LDAP://$ADDomain", $DomainUser, $DomainPassword)
        $Search        = New-Object DirectoryServices.DirectorySearcher($DomainInfo)
        $Search.Filter = "(samAccountName=$($computerName)$)"

        if ($Comp = $Search.FindOne()) {
            Write-Log "removing existing entry $computerName"
            $Comp.GetDirectoryEntry().DeleteTree()
            Start-Sleep -Seconds 5
        }
    }
    else
    {
        Write-Log "Unable to remove domain name, one of domain, user, password is empty"
    }
}

function
DomainJoin-VM($newName)
{
    if ($DomainUser -ne "" -And $DomainPassword -ne "" -And $ADDomain -ne "" )
    {
        Remove-DomainNameIfExists

        $securepw = ConvertTo-SecureString $DomainPassword -AsPlainText -Force
        $joinCred = New-Object System.Management.Automation.PSCredential('azureuser', $securepw)
        if ($newName -ne "")
        {
            if ($OUPath -ne "")
            {
                Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force -NewName $newName -OUPath $OUPath
            }
            else
            {
                Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force -NewName $newName
            }
        }
        else
        {
            if ($OUPath -ne "")
            {
                Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force -OUPath $OUPath
            }
            else
            {
                Add-Computer -DomainName $ADDomain -PassThru -Verbose -Credential $joinCred -Force
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

        Disable-NonGateway-NICs

        Write-Log "Renaming VM"
        $newName = Rename-VM

        Write-Log "Joining Domain with rename to '$newName'"
        DomainJoin-VM -newName $newName

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