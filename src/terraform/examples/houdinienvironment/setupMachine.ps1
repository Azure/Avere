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
    $MountAddressesCSV = "",
    
    [string]
    $MountPath = "",

    [string]
    $TargetPath = "",

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
Install-NFS
{
    # only set if we have a the mount information and path
    if ($MountAddressesCSV -gt 0 -And $MountPath -gt 0 -And $TargetPath -gt 0 )
    {
        # install NFS
        New-ItemProperty -Path HKLM:'\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name EnableLinkedConnections -Value 1 -Type DWord
        Enable-WindowsOptionalFeature -Online -FeatureName "ServicesForNFS-ClientOnly" -All
        Enable-WindowsOptionalFeature -Online -FeatureName "NFS-Administration" -All
        Enable-WindowsOptionalFeature -Online -FeatureName "ClientForNFS-Infrastructure" -All

        # get the mount address, round robin across ip addresses
        $mount_addresses = $MountAddressesCSV -split ","
        $ipV4full = Test-Connection -ComputerName (hostname) -Count 1
        $octets = $ipV4full.IPV4Address.IPAddressToString -split "\."
        $mount_index = $octets[3] % $mount_addresses.Length
        $mount_address = $mount_addresses[$mount_index]
        
        cmd /c mklink /D ${TargetPath} "\\${mount_address}${MountPath}".replace("/","\\")
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

try
{
    # Set to false for debugging.  This will output the start script to
    # c:\AzureData\CustomDataSetupScript.log, and then you can RDP
    # to the windows machine, and run the script manually to watch
    # the output.
    if ($true)
    {
        # call function Write-TestFile to output to c:\AzureData\helloworld.txt
        Install-NFS

        Update-RDPPort

        Write-Log "Complete"
    }
    else
    {
        # keep for debugging purposes
        Write-Log "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
        Write-Log ".\CustomDataSetupScript.ps1 -MountAddressesCSV '$MountAddressesCSV' -MountPath $MountPath -TargetPath $TargetPath -RDPPort $RDPPort  "
    }
}
catch
{
    Write-Error $_
}