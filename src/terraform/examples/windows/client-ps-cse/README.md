# Windows with CustomScript Extension to Execute Powershell script

This module shows how to deploy a Windows machine with a powershell custom script extension.  The script will be gzipped and base64 encoded and passed to `custom_data` of the VM, and then executed in the custom script extension.  All script running is logged to `C:\AzureData\CustomDataSetupScript.log`.  It is useful to deliver the payload via custom_data in locked down environments, and the script stays close to Terraform.

At the bottom of the powershell script `setupMachine.ps1` the following mechanism exists to help debug your script.  Setting to `$false` will output the necessary commands to run the script after the CSE has started including the arguments.  This is useful to know the script runs correctly before running it with the custom script extension:

```powershell
    # Set to false for debugging.  This will output the start script to
    # c:\AzureData\CustomDataSetupScript.log, and then you can RDP
    # to the windows machine, and run the script manually to watch
    # the output.
    if ($true)
    {
        # call function Write-TestFile to output to c:\AzureData\helloworld.txt
        Write-TestFile

        Write-Log "Complete"
    }
    else
    {
        # keep for debugging purposes
        Write-Log "Set-ExecutionPolicy -ExecutionPolicy Unrestricted"
        Write-Log ".\CustomDataSetupScript.ps1 -UserName $UserName "
    }
```

This technique has been tested on Windows Server 2019, Windows Server 2016, and Windows 10.  The following sections highlight the important parts of the script

## Part 0 - Paths Used in this Example

Here are the paths used in this example. After the example has run look in `C:\AzureData` for the `helloworld.txt` and the `CustomDataSetupScript.log` that logs the running of the script.  Examine the other logs for information.

* `C:\AzureData` - directory where the custom data is placed

* `C:\WindowsAzure\Logs` - general logs

* `C:\WindowsAzure\Logs\WaAppAgent.log` - Azure guest agent logs

* `C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.8` - where the CSE logs are placed

## Part 1 - Arguments

In the top of the file, the following parameters are modified to adjust the arguments and powershell script name:

```terraform
  // the following are the arguments to be passed to the custom script
  windows_custom_script_arguments = "$arguments = '-UserName ${local.vm_admin_username}' ; "

  // load the powershell file, you can substitute kv pairs as you need them, but 
  // use arguments where possible
  powershell_script = templatefile("${path.module}/setupMachine.ps1", {})
```

## Part 2 - Encoded CustomData

The loaded file is gzipped and base64 encoded and passed to the `custom_data` argument as shown below:

```terraform
  custom_data           = base64gzip(local.powershell_script)
```

## Part 3 - Script Plumbing and Execution

The following is the plumbing to execute the powershell script.  This code should not need to be modified.  The script does the folllowing:

1. unzips the powershell script to file `c:\AzureData\CustomDataSetupScript.ps1`

2. executes the script using the unrestricted policy.  The script will execute in the starting directory under `C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.8`

3. all stdout and stderr output is logged to c:\AzureData\CustomDataSetupScript.log


```terraform
locals {
  // the following powershell code will unzip and de-base64 the custom data payload enabling it
  // to be executed as a powershell script
  windows_custom_script_suffix = " $inputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomData.bin' ; $outputFile = '%SYSTEMDRIVE%\\\\AzureData\\\\CustomDataSetupScript.ps1' ; $inputStream = New-Object System.IO.FileStream $inputFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read) ; $sr = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)) ; $sr.ReadToEnd() | Out-File($outputFile) ; Invoke-Expression('{0} {1}' -f $outputFile, $arguments) ; "

  windows_custom_script = "powershell.exe -ExecutionPolicy Unrestricted -command \\\"${local.windows_custom_script_arguments} ${local.windows_custom_script_suffix}\\\""
}

resource "azurerm_virtual_machine_extension" "cse" {
  name                 = "${local.unique_name}-cse"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
        "commandToExecute": "${local.windows_custom_script} > %SYSTEMDRIVE%\\AzureData\\CustomDataSetupScript.log 2>&1"
    }
SETTINGS
}
```