<#
    Copyright (C) Microsoft Corporation. All rights reserved.
    Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

    .SYNOPSIS
        Query the users and groups of the AD server and generate flat files for avere
        populated with uid/gid based on RID and start range parameter.

    .DESCRIPTION
        Query the users and groups of the AD server and generate flat files for avere
        populated with uid/gid based on RID and start range parameter.

        The files to be generated are named 'avere-user' and 'avere-group' and
        summarized in the following two documents:

            https://azure.github.io/Avere/legacy/pdf/ADAdminCIFSACLsGuide_20140716.pdf
            https://azure.github.io/Avere/legacy/ops_guide/4_7/html/gui_directory_services.html

        Example command line: .\Get-Avere-UserGroup-Flatfiles.ps1 -StartRange 1012300000
#>
[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNull()]
    [int]
    $StartRange
)

$global:UserFile = "avere-user.txt"
$global:GroupFile = "avere-group.txt"

filter Timestamp {"$(Get-Date -Format o): $_"}

function
Write-Log($message)
{
    $msg = $message | Timestamp
    Write-Output $msg
}

function
Get-RID($sid)
{
    $rid = 0
    
    $items = $sid -split "-"
    if ($items.Count > 0) {
        $lastItem = $items[$items.Count-1]
        $rid = [int]$lastItem
    }

    $StartRange + $rid
}

function
Get-Users
{
    $allUsers = Get-ADUser -Filter * -Properties SamAccountName, SID, MemberOf, DistinguishedName | Select-Object -Property SamAccountName, SID, MemberOf, DistinguishedName
    ForEach($targetUser in $allUsers){
        @{
            SamAccountName = $targetUser.SamAccountName
            RID = Get-RID $targetUser.SID
            MemberOf = $targetUser.MemberOf
            DistinguishedName = $targetUser.DistinguishedName
        }
    }
}

function
Get-Groups
{
    $allGroups = Get-ADGroup -Filter * -Properties SamAccountName, SID, Members, DistinguishedName | Select-Object -Property SamAccountName, SID, Members, DistinguishedName
    ForEach($targetGroup in $allGroups){
        @{
            SamAccountName = $targetGroup.SamAccountName
            RID = Get-RID $targetGroup.SID
            Members = $targetGroup.Members
            DistinguishedName = $targetGroup.DistinguishedName
        }
    }
}

function
Get-Gid($avereUser, $distinguishedNameMap) {
    $gid = $avereUser.RID

    ForEach($group in $avereGroup.MemberOf) {
        if ($distinguishedNameMap.ContainsKey($group)) {
            $gid = $distinguishedNameMap[$group].RID
            break
        }
    }

    $gid
}

function
Get-Members($avereGroup, $distinguishedNameMap) {
    $members = @()

    ForEach($member in $avereGroup.Members) {
        if ($distinguishedNameMap.ContainsKey($member)) {
            $members += $distinguishedNameMap[$member].SamAccountName
        }
    }

    $members -join ","
}

function
Write-AvereFiles($avereUsers, $avereGroups)
{
    $distinguishedNameMap = @{}
    ForEach($avereUser in $avereUsers) {
        $distinguishedNameMap[$avereUser.DistinguishedName] = $avereUser
    }
    ForEach($avereGroup in $avereGroups) {
        $distinguishedNameMap[$avereGroup.DistinguishedName] = $avereGroup
    }
    $avereUserFileContents = ""
    ForEach($avereUser in $avereUsers) {
        $user = $avereUser.SamAccountName
        $rid = $avereUser.RID
        $gid = Get-Gid -avereUser $avereUser -distinguishedNameMap $distinguishedNameMap
        $avereUserFileContents += "${user}:*:${rid}:${gid}:::`n"
    }
    $avereUserFileContents | Out-File -encoding ASCII -filepath "$global:UserFile" -NoNewline

    $avereGroupFileContents = ""
    ForEach($avereGroup in $avereGroups) {
        $groupName = $avereGroup.SamAccountName
        $rid = $avereGroup.RID
        $members = Get-Members -avereGroup $avereGroup -distinguishedNameMap $distinguishedNameMap
        $avereGroupFileContents += "${groupName}:*:${rid}:${members}`n"
    }
    $avereGroupFileContents | Out-File -encoding ASCII -filepath "$global:GroupFile" -NoNewline
}

try
{
    Write-Log("retrieve users")
    $avereUsers = Get-Users

    Write-Log("retrieve groups")
    $avereGroups = Get-Groups

    Write-Log("write file '$global:UserFile' and file '$global:GroupFile'")
    Write-AvereFiles -avereUsers $avereUsers -avereGroups $avereGroups
}
catch
{
    Write-Error $_
}