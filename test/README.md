[![Build Status](https://dev.azure.com/averevfxt/vfxt-github/_apis/build/status/Azure.Avere?branchName=main)](https://dev.azure.com/averevfxt/vfxt-github/_build/latest?definitionId=1?branchName=main)

# Avere vFXT ARM Template Testing

This directory contains automated tests using ARM-based templates to deploy Avere vFXT clusters and associated resources, including clients for various test scenarios. The primary scope of these tests is to validate the effectiveness and usability of the ARM templates. Additionally, some vFXT feature and performance tests are included.

## Requirements
Tests are written in [Python 3](https://www.python.org/) using the [Microsoft Azure SDK for Python](https://pypi.org/project/azure-mgmt-resource/) and the [pytest](https://docs.pytest.org/en/latest/) framework. See [requirements.txt](requirements.txt) for other dependencies.

### Environment Variables
These tests assume the following environment variables exist when running the tests. See [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/) for information on storing your secrets securely.

| Environment Variable   | Description
|------------------------|------------
| AVERE_ADMIN_PW         | The password for the Avere vFXT cluster.
| AVERE_CONTROLLER_PW    | The password for the Avere vFXT controller.
| AZURE_CLIENT_ID        | The Azure client ID.
| AZURE_CLIENT_SECRET    | The Azure client password (secret).
| AZURE_SUBSCRIPTION_ID  | The Azure subscription under which to deploy resources.
| AZURE_TENTANT_ID       | The Azure tentant ID.
| BUILD_SOURCESDIRECTORY | The local root directory for a clone of the [Azure/Avere repo](https://github.com/Azure/Avere).

## How To Run Tests
Tests can be invoked by the usual [pytest](https://docs.pytest.org/en/latest/) methods. The simplest way to run all of the tests is to simply run "pytest" from the $BUILD_SOURCESDIRECTORY directory. However, that method should **not** be used because multiple deployments will then be initiated back-to-back, and failures due to name conflicts and or quota usage are likely to occur.

The recommended method for running these tests is to first call a specific deploy test. Example:

    pytest test/test_vfxt_template_deploy.py::TestVfxtTemplateDeploy::test_deploy_template

That will run the **test_deploy_template** test in the [test_vfxt_template_deploy.py](test_vfxt_template_deploy.py) file.

After the cluster has been deployed, any of the other test_*.py files can be run.

*(placeholder -- link to plan, DevOps or otherwise)*

### Custom Command-Line Arguments
When running the tests, the standard [pytest command-line arguments](https://docs.pytest.org/en/latest/reference.html#ini-options-ref) are available. In addition, the following custom command-line options are available:

    $ pytest --help

    ...

    custom options:
      --build_root=BUILD_ROOT
                            Local path to the root of the Azure/Avere repo clone
                            (e.g., /home/user1/git/Azure/Avere). This is used to
                            find the various templates that are deployed during
                            these tests. (default: $BUILD_SOURCESDIRECTORY if set,
                            else current directory)
      --location=LOCATION   Azure region short name to use for deployments
                            (default: westus2)
      --prefer_cli_args     When specified, prioritize custom command-line
                            arguments over the values in the file pointed to by
                            "test_vars_file".
      --ssh_priv_key=SSH_PRIV_KEY
                            SSH private key to use in deployments and tests
                            (default: ~/.ssh/id_rsa)
      --ssh_pub_key=SSH_PUB_KEY
                            SSH public key to use in deployments and tests
                            (default: ~/.ssh/id_rsa.pub)
      --test_vars_file=TEST_VARS_FILE
                            Test variables file used for passing values between
                            runs. This file is in JSON format. It is loaded during
                            test setup and written out during test teardown. The
                            contents of this file override other custom command-
                            line options unless the "prefer_cli_args" option is
                            specified. (default: $VFXT_TEST_VARS_FILE if set, else
                            None)

    ...

Arguments are defined in [conftest.py](conftest.py).

# Internal Use
The following sections are for internal Microsoft use only.

## Pipelines Variables
The following Pipelines variables are available in DevOps and control how queued Pipelines run.

| Variable             | Default | Description
|----------------------|---------|------------
| RUN_BYOVNET          | false   | When "true", run the "bring your own VNET" variant (test_byovnet_deploy in [test_vfxt_template_deploy.py](test_vfxt_template_deploy.py).
| RUN_DEPLOY           | true    | When "true", run the "create a new VNET" variant (test_template_deploy in [test_vfxt_template_deploy.py](test_vfxt_template_deploy.py).
| RUN_EDASIM_STEP      | true    | When "true", run the EDASIM tests [test_edasim.py](test_edasim.py).
| RUN_EMPTY_STORAGE    | false   | When "true", run the "no blob storage, no storage account needed" variant (test_no_storage_account_deploy in [test_vfxt_template_deploy.py](test_vfxt_template_deploy.py).
| RUN_VDBENCH_STEP     | false   | When "true", run the vdbench tests [test_vdbench.py](test_vdbench.py).
| SKIP_RG_CLEANUP      | false   | When "true", do **not** clean up the resource group at the end of the Pipelines run.
| VFXT_DEPLOY_LOCATION | westus2 | The Azure region short name to which to deploy resources.
