# Template Testing

[![Build Status](https://dev.azure.com/averevfxt/vfxt-github/_apis/build/status/Azure.Avere?branchName=master)](https://dev.azure.com/averevfxt/vfxt-github/_build/latest?definitionId=1?branchName=master)

Test coverage for using an auto generated template and deploying to Azure.

[Tutorial to deploy with the template and deploy.](https://github.com/Azure/Avere/tree/master/src/vfxt)

For the tests we are using the [Microsoft Azure SDK for Python](https://pypi.org/project/azure-mgmt-resource/).

See **requirements.txt** for Python module dependencies.

Our test framework is pytest.

Test Files:
* arm_template_deploy.py
* conftest.py
* test_vfxt_cluster_status.py
* test_vfxt_template_deploy.py
* lib/
  * helpers.py

**Scenarios:**
1. **Deploy vFXT using the template**
   * Create resource group
   * Deploy vFXT template (with cloud tracing turned on)
   * Perform basic cluster health checks
     * mount all nodes on controller
     * use AvereOS API to check cluster health, HA status, etc.
     * ping nodes
   * Collect test artifacts
   * Delete resource group
2. (TBD -- vdbench)
3. (TBD -- EDASIM)
4. (TBD)

