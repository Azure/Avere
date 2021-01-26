# SMB Walker

The SMB Walker walks all the SMB frontends of an Avere vFXT.  It is driven by dns, so in the following call, it will spawn a thread for each ip address resolved from "assetfiler.rendering.com", and read bytes from each png file found.  

```bash
smbwalker \\assetfiler.rendering.com\assets\scene1 *.png
```

# Install instructions

To install on Windows, run the following instructions:

1. open a powershell
1. execute the following commands to install go and download this example:
```powershell
mkdir c:\gowork
cd c:\gowork
Invoke-WebRequest https://golang.org/dl/go1.15.7.windows-amd64.msi
https://golang.org/dl/go1.15.7.windows-amd64.msi
mkdir smbwalker
cd smbwalker
Invoke-WebRequest https://raw.githubusercontent.com/Azure/Avere/main/src/go/cmd/smbwalker/main.go
go build
```
1. once installed run the walker against your avere.  The following command will walk all shares of the Avere and read bytes from all *.png files
```powershell
smbwalker \\assetfiler.rendering.com\assets\scene1 *.png
```
