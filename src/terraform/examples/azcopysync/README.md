# Testing azcopy sync command

This examples creates a windows VM, and storage account for purpose of showing the azcopy sync command, where filer is directory in your cloudshell.

![The architecture](../../../../../docs/images/terraform/azcopysyncscenario.png)

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.

1. browse to https://shell.azure.com

2. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin master
```

3. `cd src/terraform/examples/azcopysync`

4. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences.

5. execute `terraform init` in the directory of `main.tf`.

6. execute `terraform apply -auto-approve` to deploy.

7. once, run the az commands from the output to get your SAS URL (copy and paste it somewhere):

```bash
export SAS_URL="${SAS_PREFIX}${SAS_POSTFIX}"
echo $SAS_URL
```

8. For this example, we'll use the tf directory created in this tutorial, sync your ~/tf directory to the storage account:
```bash
azcopy sync ~/tf $SAS_URL
```

9. RDP to the windows machine using the username and address from the output variables

10. Install azcopy from https://aka.ms/downloadazcopy-v10-windows.  Open powershell as administrator and type:

```powershell
mkdir \azcopy
cd \azcopy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://aka.ms/downloadazcopy-v10-windows
Expand-Archive azcopy.zip
copy .\azcopy\azcopy_windows_amd64_10.3.4\azcopy.exe c:\windows\system32\.
```

10. create the data directory and map to v:\ drive
```powershell
mkdir c:\data
subst v: c:\data
```

10. create the sync files, and run the syncfrom

```powershell
echo "azcopy sync 'SASURL' c:\data" > c:\azcopy\syncfrom.ps1
echo "azcopy sync c:\data 'SASURL' " > c:\azcopy\syncwork.ps1
c:\azcopy\syncfrom.ps1
```

11. Try creating some files and observe that `syncfrom.ps1` doesn't clobber the files.  Observe that `syncwork.ps1` uploads the new files correctly

The end result is that you now have a "V:\" drive containing the files of the original tf folder:

![shows the vdrive](vdrive.png)

Note that the storage account has "softdelete" on for 7 days and will preserve files in case of accidental overwrites or deletions.

When you are done with the example, you can destroy it by running `terraform destroy -auto-approve` or just delete the resource group created.