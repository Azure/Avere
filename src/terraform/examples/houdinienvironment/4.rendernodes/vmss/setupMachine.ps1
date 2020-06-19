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
    [ValidateNotNullOrEmpty()]
    $UserName,

    [string]
    [ValidateNotNullOrEmpty()]
    $MountIP,
    
    [string]
    [ValidateNotNullOrEmpty()]
    $MountPath,

    [string]
    [ValidateNotNullOrEmpty()]
    $TargetPath,
)

# the windows packages we want to remove
$global:AppxPkgs = @(
        "*windowscommunicationsapps*"
        "*windowsstore*"
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
    New-ItemProperty -Path HKLM:'\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name EnableLinkedConnections -Value 1 -Type DWord
    Enable-WindowsOptionalFeature -Online -FeatureName "ServicesForNFS-ClientOnly" -All
    Enable-WindowsOptionalFeature -Online -FeatureName "NFS-Administration" -All
    Enable-WindowsOptionalFeature -Online -FeatureName "ClientForNFS-Infrastructure" -All
    cmd /c mklink /D ${TargetPath} "\\${MountIP}${MountPath}".replace("/","\\")
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

        Write-Log "Complete"
    }
    else
    {
        # keep for debugging purposes
        Write-Log "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
        Write-Log ".\CustomDataSetupScript.ps1 -UserName $UserName "
    }
}
catch
{
    Write-Error $_
}