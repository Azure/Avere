<#
    Copyright (C) Microsoft Corporation. All rights reserved.
    Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

    .SYNOPSIS
        Query the users and groups of the AD server and generate flat files for avere
        populated with uid/gid from the RFC2307 parameters: uidNumber, gidNumber

    .DESCRIPTION
        Query the users and groups of the AD server and generate flat files for avere
        populated with uid/gid based on RID and start range parameter.

        The files to be generated are named 'avere-user' and 'avere-group' and
        summarized in the following two documents:

            https://azure.github.io/Avere/legacy/pdf/ADAdminCIFSACLsGuide_20140716.pdf
            https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_directory_services.html

        Example command line: .\Get-AvereFlatFilesRFC2307.ps1
#>
[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [string]
    $UserFile = "avere-user.txt",

    [string]
    $GroupFile = "avere-group.txt"
)

filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message)
{
    $msg = $message | Timestamp
    Write-Output $msg
}

function
Get-Users
{
    $allUsers = Get-ADUser -Filter * -Properties SamAccountName, uidNumber, gidNumber | Select-Object -Property SamAccountName, uidNumber, gidNumber | where-object uidNumber -Gt 0 | where-object gidNumber -Gt 0
    ForEach($targetUser in $allUsers){
        @{
            SamAccountName = $targetUser.SamAccountName
            uidNumber = $targetUser.uidNumber
            gidNumber = $targetUser.gidNumber
        }
    }
}

function
Get-Groups
{
    $allGroups = Get-ADGroup -Filter * -Properties SamAccountName, gidNumber | Select-Object -Property SamAccountName, gidNumber | where-object gidNumber -Gt 0 
    ForEach($targetGroup in $allGroups){
        @{
            SamAccountName = $targetGroup.SamAccountName
            gidNumber = $targetGroup.gidNumber
        }
    }
}

function
Write-AvereFiles($avereUsers, $avereGroups)
{
    Write-Log("preparing users file")
    $avereUserFileContents = ""
    ForEach($avereUser in $avereUsers) {
        $user = $avereUser.SamAccountName
        $uid = $avereUser.uidNumber
        $gid = $avereUser.gidNumber
        $avereUserFileContents += "${user}:*:${uid}:${gid}:::`n"
    }
    $avereUserFileContents | Out-File -encoding ASCII -filepath "$UserFile" -NoNewline

    $userNameMap = @{}
    ForEach($avereUser in $avereUsers) {
        $userNameMap[$avereUser.SamAccountName] = $avereUser
    }
    
    Write-Log("preparing groups file")
    $avereGroupFileContents = ""
    ForEach($avereGroup in $avereGroups) {
        $groupName = $avereGroup.SamAccountName
        $gid = $avereGroup.gidNumber
        $members = (Get-ADGroupMember $avereGroup.SamAccountName | Where { $_.objectClass -eq "user" -And $userNameMap.ContainsKey($_.SamAccountName) } | select -expand SamAccountName) -join ","
        if ($members.length -gt 0) {
            $avereGroupFileContents += "${groupName}:*:${gid}:${members}`n"
        }
    }
    $avereGroupFileContents | Out-File -encoding ASCII -filepath "$GroupFile" -NoNewline
}

try
{
    Write-Log("retrieve users")
    $avereUsers = Get-Users

    Write-Log("retrieve groups")
    $avereGroups = Get-Groups

    Write-Log("write file '$UserFile' and file '$GroupFile'")
    Write-AvereFiles -avereUsers $avereUsers -avereGroups $avereGroups

    Write-Log("complete")
}
catch
{
    Write-Error $_
}