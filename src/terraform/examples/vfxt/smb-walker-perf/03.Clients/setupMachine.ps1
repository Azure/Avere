<#
    .SYNOPSIS
        Configure Windows 10 Workstation with Media.

    .DESCRIPTION
        Configure Windows 10 Workstation with Media.

        Example command line: .\startupAvere azureuser 172.16.0.15 172.16.0.22 msazure
#>


[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [int]
    [ValidateNotNullOrEmpty()]
    $RdpPort
)

filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message)
{
    $msg = $message | Timestamp
    Write-Output $msg
}

function
Set-RdpPort($RDPPort)
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
Write-TestFile()
{
    Add-Content -Path "$env:SYSTEMDRIVE\\AzureData\\helloworld.txt" -Value "$RdpPort"
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
        Write-TestFile
        Set-RdpPort $RdpPort

        Write-Log "Complete"
    }
    else
    {
        # keep for debugging purposes
        Write-Log "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
        Write-Log ".\CustomDataSetupScript.ps1 -RdpPort $RdpPort "
    }
    exit 0;
}
catch
{
    Write-Error $_
}