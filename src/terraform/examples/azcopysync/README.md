# Testing azcopy sync command

The purpose of this example is to show how the `azcopy sync` command can be used to keep remote artists in sync with a central source of data.  This example creates a storage account with a 7 day deletion retention policy, meaning if there are deletes or modifications of files between artists, these can be recovered.

This examples creates a windows VM, and an storage account, where the on-prem filer is a directory in your cloudshell.

![The architecture](../../../../docs/images/terraform/azcopysyncscenario.png)

## Deployment Instructions

To run the example, execute the following instructions.  This assumes use of Azure Cloud Shell.

1. browse to https://shell.azure.com

2. Specify your subscription by running this command with your subscription ID:  ```az account set --subscription YOUR_SUBSCRIPTION_ID```.  You will need to run this every time after restarting your shell, otherwise it may default you to the wrong subscription and your resources will end up in that subscription.

3. get the terraform examples
```bash
mkdir tf
cd tf
git init
git remote add origin -f https://github.com/Azure/Avere.git
git config core.sparsecheckout true
echo "src/terraform/*" >> .git/info/sparse-checkout
git pull origin master
```

4. `cd src/terraform/examples/azcopysync`

5. `code main.tf` to edit the local variables section at the top of the file, to customize to your preferences.

6. execute `terraform init` in the directory of `main.tf`.

7. execute `terraform apply -auto-approve` to deploy.

8. once, run the az commands from the output to get your SAS URL (copy and paste it somewhere):

```bash
### begin output commands (copy paste from the terraform output commands)
export SAS_PREFIX=https://abanhowestorageaccount.blob.core.windows.net/previz?
export SAS_SUFFIX=$(az storage container generate-sas --account-name abanhowestorageaccount --https-only --permissions acdlrw --start 2020-04-06T00:00:00Z --expiry 2021-01-01T00:00:00Z --name previz --output tsv)
#### end output commands

export SAS_URL="${SAS_PREFIX}${SAS_SUFFIX}"
echo $SAS_URL
```

9. For this example, we'll use the tf directory created in this tutorial, sync your ~/tf directory to the storage account:
```bash
azcopy sync ~/tf $SAS_URL
```

10. using the `rdp_address` and `rdp_username` from the terraform output variables, RDP to the windows machine using the username and address from the output variables

11. Open powershell as administrator and use the following commands to install azcopy from https://aka.ms/downloadazcopy-v10-windows:

```powershell
mkdir \azcopy
cd \azcopy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://aka.ms/downloadazcopy-v10-windows -OutFile azcopy.zip
Expand-Archive azcopy.zip
copy .\azcopy\azcopy_windows_amd64_10.3.4\azcopy.exe c:\windows\system32\.
```

12. create the data directory and map to v:\ drive
```powershell
mkdir c:\data
subst v: c:\data
```

13. using the SAS URL you created earlier create the sync files, and run the `syncfrom.ps1`

```powershell
$env:SAS_URL='' # paste the SAS_URL value from the cloudshell in the single quotes
"azcopy sync '$env:SAS_URL' c:\data" > c:\azcopy\syncfrom.ps1
"azcopy sync c:\data '$env:SAS_URL'" > c:\azcopy\syncto.ps1
# uncomment below for Windows 10
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force
c:\azcopy\syncfrom.ps1
```

14. Try creating some files and observe that `c:\azcopy\syncfrom.ps1` doesn't clobber the files.  Observe that `c:\azcopy\syncto.ps1` uploads the new files correctly, by adjusting the order of path from your previous cloud shell.  In explorer browse to `V:\` drive.

The end result is that you now have a `V:\` drive containing the files of the original tf folder:

![shows the vdrive](vdrive.png)

Note that the storage account has "softdelete" on for 7 days and will preserve files in case of accidental modifications or deletions.

When you are done with the example, you can destroy it by running `terraform destroy -auto-approve` or just delete the resource group created.