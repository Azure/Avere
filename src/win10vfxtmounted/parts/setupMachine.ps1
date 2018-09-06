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
    $AvereManagementIP,
    
    [string]
    [ValidateNotNullOrEmpty()]
    $AvereMountIP,
    
    [string]
    [ValidateNotNullOrEmpty()]
    $AvereMountPath
)

# the drive letter is hardcoded for now, but may become a parameter
$global:TargetDriveLetter = "v"
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
Remove-WindowsApps($UserPath) 
{
    ForEach($app in $global:AppxPkgs){
        Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
    }
    try
    {
        ForEach($app in $global:AppxPkgs){
            Get-AppxPackage -Name $app | Remove-AppxPackage -User $UserPath -ErrorAction SilentlyContinue
        }
    }
    catch
    {
        # the user may not be created yet, but in case it is we want to remove the app
    }
    
    Remove-Item "c:\Users\Public\Desktop\Short_survey_to_provide_input_on_this_VM..url"
}

function
Install-DesktopLinks($UserPath) 
{
    # add the mount point
    $wshshell = New-Object -ComObject WScript.Shell
    $lnk = $wshshell.CreateShortcut("c:\Users\$UserPath\Desktop\AvereVFXT.lnk")
    $lnk.TargetPath = "c:\AvereVFXT"
    $lnk.Save()

    #add a link to the desktop for Batch Explorer
    $wshshell = New-Object -ComObject WScript.Shell
    $lnk = $wshshell.CreateShortcut("c:\Users\$UserPath\Desktop\BatchExplorer.lnk")
    $lnk.TargetPath = "C:\Program Files\AzureBatchExplorer\BatchLabs.exe"
    $lnk.Save()

    #add a link to the desktop for Storage Explorer
    $wshshell = New-Object -ComObject WScript.Shell
    $lnk = $wshshell.CreateShortcut("c:\Users\$UserPath\Desktop\StorageExplorer.lnk")
    $lnk.TargetPath = "C:\Program Files (x86)\Microsoft Azure Storage Explorer\StorageExplorer.exe"
    $lnk.Save()

    #add a link to the desktop for Virtual Dub
    $wshshell = New-Object -ComObject WScript.Shell
    $lnk = $wshshell.CreateShortcut("c:\Users\$UserPath\Desktop\VirtualDub.lnk")
    $lnk.TargetPath = "C:\Program Files\VirtualDub\VirtualDub.exe"
    $lnk.Save()

     #add a link to the desktop for Notepad++
     $wshshell = New-Object -ComObject WScript.Shell
     $lnk = $wshshell.CreateShortcut("c:\Users\$UserPath\Desktop\Notepad++.lnk")
     $lnk.TargetPath = "C:\Program Files\Notepad++\notepad++.exe"
     $lnk.Save()

        #add a link to the desktop for the management URL
    $wshshell = New-Object -ComObject WScript.Shell
    $lnk = $wshshell.CreateShortcut("c:\Users\$UserPath\Desktop\AvereMgmt.lnk")
    $lnk.TargetPath = "https://${AvereManagementIP}/avere/fxt/index.php"
    $AvereIconDestinationPath =  "C:\Windows\System32\avere.ico"
    $AvereIconUrl = "https://avereimageswestus.blob.core.windows.net/archive/avere.ico"
    DownloadFileOverHttp $AvereIconUrl $AvereIconDestinationPath
    $lnk.IconLocation = "$AvereIconDestinationPath, 0"
    $lnk.Save()
}

function
Write-StartupFile
{
    $startupFileContents = @"
# setup the home button in the startup file
# the best we can do is set the home button as described here: https://www.reddit.com/r/PowerShell/comments/7ooic9/help_with_script_microsoft_edge_homepage/
REG ADD "HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage\microsoft.microsoftedge_8wekyb3d8bbwe\MicrosoftEdge\Main" /v "HomeButtonPage" /t REG_SZ /d "https://${AvereManagementIP}/avere/fxt/index.php" /f
REG ADD "HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage\microsoft.microsoftedge_8wekyb3d8bbwe\MicrosoftEdge\Main" /v "HomeButtonEnabled" /t REG_DWORD /d 1 /f
REM EnableLinkedConnections is broken in Win 10 Oct Edition, so we are creating a symbolic link for now
REM net use ${global:TargetDriveLetter}: \\${AvereMountIP}${AvereMountPath}

"@
    ForEach($app in $global:AppxPkgs){
        $startupFileContents += "`npowershell.exe -ExecutionPolicy Unrestricted -command ""`$ProgressPreference = 'SilentlyContinue' ; Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue"""
    }
        
    mkdir "C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
    $startFilePath = "C:\\Users\\Default\\AppData\\Roaming\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\SetupAvere.bat"
    $startupFileContents | Out-File -encoding ASCII -filepath "$startFilePath"
}

function
Install-NFS
{
    New-ItemProperty -Path HKLM:'\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name EnableLinkedConnections -Value 1 -Type DWord
    Enable-WindowsOptionalFeature -Online -FeatureName "ServicesForNFS-ClientOnly" -All
    Enable-WindowsOptionalFeature -Online -FeatureName "NFS-Administration" -All
    Enable-WindowsOptionalFeature -Online -FeatureName "ClientForNFS-Infrastructure" -All
    cmd /c mklink /D c:\AvereVFXT "\\${AvereMountIP}${AvereMountPath}".replace("/","\\")
}

function
Install-AzureBatchExplorer
{
    $DestinationPath =  "C:\AzureData\AzureBatchExplorer.zip"
    $Url = "https://github.com/Azure/BatchExplorer/releases/download/v0.15.0/0.15.0.BatchLabs-win.zip"
    DownloadFileOverHttp $Url $DestinationPath
    Expand-Archive -path $DestinationPath -DestinationPath "C:\Program Files\AzureBatchExplorer"
}

function
Install-VirtualDub
{
    $DestinationPath =  "C:\AzureData\VirtualDub.zip"
    $Url = "https://downloads.sourceforge.net/project/virtualdub/virtualdub-win/1.10.4.35491/VirtualDub-1.10.4.zip"
    # the normal download won't work because of the required user agent
    #DownloadFileOverHttp $Url $DestinationPath
    # make Invoke-WebRequest go fast: https://stackoverflow.com/questions/14202054/why-is-this-powershell-code-invoke-webrequest-getelementsbytagname-so-incred
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $Url -OutFile $DestinationPath -UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::Edge

    Expand-Archive -path $DestinationPath -DestinationPath "C:\Program Files\VirtualDub"
}

function
Install-ChocolatyAndPackages
{
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Log "choco install -y 7zip.install"
    choco install -y 7zip.install
    Write-Log "choco install -y putty.install"
    choco install -y putty.install
    Write-Log "choco install -y notepadplusplus.install"
    choco install -y notepadplusplus.install
    Write-Log "choco install -y microsoftazurestorageexplorer"
    choco install -y microsoftazurestorageexplorer
    #Write-Log "choco install -y git.install"
    #choco install -y git.install
    #Write-Log "choco install -y python2"
    #choco install -y python2
    #Write-Log "choco install -y vscode"
    #choco install -y vscode --params "/NoDesktopIcon"
    #Write-Log "choco install -y wireshark"
    #choco install -y wireshark
    #Write-Log "choco install -y winscp"
    #choco install -y winscp
    #Write-Log "choco install -y winmerge"
}

function
Install-WindowsPacks
{
    Write-Log "Debug Install-WindowsPacks"

    #install the windows media feature
    # How do we get a non-expiring link from: https://www.microsoft.com/en-us/software-download/mediafeaturepack?
    # $WindowsMediaFeaturePackUrl = "https://software-download.microsoft.com/pr/Windows_MediaFeaturePack_x64_1709.msu?t=502e9f8c-4b72-4bd4-b8fd-bbe0eec6f3d0&e=1533550263&h=a59f3e3f9bd51b3665b0f3724a2b4346"

    # install the windows pack
    $DestinationPath =  "C:\AzureData\Windows_Pack_x64_1709.msu"
    $DestinationLog =  "C:\AzureData\Windows_Pack_x64_1709.txt"
    $WindowsPackUrl = "https://avereimageswestus.blob.core.windows.net/archive/Windows_Pack_x64_1709.msu"
    DownloadFileOverHttp $WindowsPackUrl $DestinationPath
    Write-Log "installing Windows pack: Wusa.exe $DestinationPath /quiet /log:$DestinationLog"
    Wusa.exe "$DestinationPath" /quiet /log:$DestinationLog
    Write-Log "finished installing windows pack"
}

try
{
    # Set to false for debugging.  This will output the start script to
    # c:\AzureData\CustomDataSetupScript.log, and then you can RDP
    # to the windows machine, and run the script manually to watch
    # the output.
    if ($true)
    {
        Write-Log("clean-up windows apps")
        Remove-WindowsApps $UserName

        Write-Log "Writing batch file"
        Write-StartupFile
        
        Write-Log "Install NFS"
        Install-NFS

        try
        {
            Write-Log "Installing chocolaty and packages"
            Install-ChocolatyAndPackages
        }
        catch
        {
            # chocolaty is best effort
        }

        Write-Log "Writing Desktop Links"
        Install-DesktopLinks "Default"

        try
        {
            Install-DesktopLinks $UserName
        }
        catch
        {
            # the user path may or may not be here
        }

        Write-Log "Install Windows Packs and restart"
        Install-WindowsPacks
        #
        # install windows packs takes about 10 minutes to install, and will reboot
        # the commands below should not exceed 10 minutes 
        #
        Write-Log "Install Azure Batch Explorer"
        Install-AzureBatchExplorer

        Write-Log "Install VirtualDub"
        Install-VirtualDub

        Write-Log "Complete"
    }
    else
    {
        # keep for debugging purposes
        Write-Log "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
        Write-Log ".\CustomDataSetupScript.ps1 -UserName $UserName -AvereManagementIP $AvereManagementIP -AvereMountIP $AvereMountIP -AvereMountPath $AvereMountPath"
    }
}
catch
{
    Write-Error $_
}