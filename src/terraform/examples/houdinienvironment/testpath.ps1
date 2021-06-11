# the following file tests to/from path, and works on regular windows paths and SMB Paths
[CmdletBinding(DefaultParameterSetName = "Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $PathName
)

filter Timestamp { "$(Get-Date -Format o): $_" }

function
Write-Log($message) {
    $msg = $message | Timestamp
    Write-Output $msg
}

# inspired by https://stackoverflow.com/questions/7195337/how-do-i-get-a-path-with-the-correct-canonical-case-in-powershell
$getPathNameSignature = @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern uint GetLongPathName(
    string shortPath, 
    StringBuilder sb, 
    int bufferSize);

[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError=true)]
public static extern uint GetShortPathName(
   string longPath,
   StringBuilder shortPath,
   uint bufferSize);
'@
$getPathNameType = Add-Type -MemberDefinition $getPathNameSignature -Name GetPathNameType -UsingNamespace System.Text -PassThru


try {
    Write-Log "Analyzing Path '$PathName'"

    if ( -not (Test-Path $PathName) ) {
        Write-Error "Path '$PathName' doesn't exist."
        return
    }

    $shortBuffer = New-Object Text.StringBuilder ($PathName.Length * 2)
    [void] $getPathNameType::GetShortPathName( $PathName, $shortBuffer, $shortBuffer.Capacity )

    $txt = "ShortPathName '" + $shortBuffer.ToString() + "'"
    Write-Log $txt

    if ( -not (Test-Path $shortBuffer.ToString()) ) {
        $txt = "Path '" + $shortBuffer.ToString() + "' doesn't exist."
        Write-Log $txt
        return
    }

    $longBuffer = New-Object Text.StringBuilder ($PathName.Length * 2)
    [void] $getPathNameType::GetLongPathName( $shortBuffer.ToString(), $longBuffer, $longBuffer.Capacity )

    if ( -not (Test-Path $longBuffer.ToString()) ) {
        $txt = "Path '" + $longBuffer.ToString() + "' doesn't exist."
        Write-Log $txt
        return
    }

    $txt = "LongPathName '" + $longBuffer.ToString() + "'"
    Write-Log $txt
    
    Write-Log "Complete"
}
catch {
    Write-Error $_
}


