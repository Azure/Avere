# Template Testing

[![Build Status](https://dev.azure.com/averevfxt/nov20-testdep/_apis/build/status/Azure.Avere)](https://dev.azure.com/averevfxt/nov20-testdep/_build/latest?definitionId=1)

Test coverage for using an auto generated template and deploying to azure.

Tutorial to do use the auto generated [template and deploy.](https://github.com/Azure/Avere/tree/master/src/vfxt)

For the tests we are using the [Microsoft Azure SDK for Python.](https://pypi.org/project/azure-mgmt-resource/)

This pip install is being done for us in the requirements.txt

We are also going to be using pytest to verify the results that we are going to verify the results from the template.


**Scenarios:**
1. **Deploy vFXT using the template**
  * Download Template
  * Create Resource Group
  * Deploy Template
  * Verify Resources
  * Clean-up Resource Group
2. **Run vdbench** 
  * Download Template
  * Create Resource Group
  * Deploy Template
  * Verify Resources
  * Download VDBench Template
  * Deploy VDBench Template
  * [Run vdBench](https://github.com/Azure/Avere/blob/master/docs/vdbench.md)
  * Verify vdbench

3. **Soak Test (7day vfxt) D16v3x3**
  * delete previous template deployment using AZ CLI
  * deploy new vfxt using the template
  * run vdbench every hour
  * bonus (canary region)

