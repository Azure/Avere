# SMB Walker

The SMB Walker walks all the SMB frontends of an Avere vFXT.  It is driven by dns, so in the following call, it will spawn a thread for each ip address resolved from "assetfiler.rendering.com", and read bytes from each png file found.  

```bash
smbwalker \\assetfiler.rendering.com\assets\scene1 *.png
```

# Install instructions

To install on Windows, run the following instructions:

1. open a powershell as administrator

1. execute the following commands to install go and download and install go.  Choose all defaults on the installer:
```powershell
mkdir c:\gowork
cd c:\gowork
# make Invoke-WebRequest go fast: https://stackoverflow.com/questions/14202054/why-is-this-powershell-code-invoke-webrequest-getelementsbytagname-so-incred
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest https://golang.org/dl/go1.15.7.windows-amd64.msi -OutFile c:\gowork\go1.15.7.windows-amd64.msi -Verbose
c:\gowork\go1.15.7.windows-amd64.msi
Remove-Item c:\gowork\go1.15.7.windows-amd64.msi
```

1. set the path for go
```powershell
$Env:PATH = "$Env:PATH;c:\go\bin"
```

1. build the walker
```powershell
mkdir c:\gowork\smbwalker
cd c:\gowork\smbwalker
Invoke-WebRequest https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/smbwalker/main.go -OutFile c:\gowork\smbwalker\main.go -Verbose
go build
```

1. once installed run the walker against your avere.  The following command will walk all shares of the Avere and read bytes from all *.png files
```powershell
.\smbwalker.exe \\assetfiler.rendering.com\assets\scene1 *.png
```
