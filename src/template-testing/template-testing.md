# Template Testing

Test coverage for using an auto generated template and deploying to azure.

Tutorial to do use the auto generated [template and deploy.](https://github.com/Azure/Avere/tree/master/src/vfxt)

For the tests we are using the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/?view=azure-cli-latest)

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
  * [Run vdench](https://github.com/Azure/Avere/blob/master/docs/vdbench.md)
  * Verify vdbench

3. **Soak Test (7day vfxt) D16v3x3**
  * delete previous template deployment using AZ CLI
  * deploy new vfxt using the template
  * run vdbench every hour
  * bonus (canary region)

