#!/usr/bin/python3

"""
Driver for testing template-based deployment of the Avere vFXT product.
"""

import argparse
import json
import sys
import time

from avere_template_deploy import AvereTemplateDeploy


# TEST CASES ##################################################################
class TestDeployment:
    atd = AvereTemplateDeploy()

    def test_create_resource_group(self):
        # 2018-1231: TURNED OFF FOR NOW
        # rg = TestDeployment.atd.create_resource_group()
        # print('> Created Resource Group: {}'.format(rg))
        pass

    def test_deploy_template(self):
        # 2018-1231: TURNED OFF FOR NOW
        # wait_for_op(TestDeployment.atd.deploy())
        pass

    def test_delete_resource_group(self):
        # 2018-1231: TURNED OFF FOR NOW
        # wait_for_op(TestDeployment.atd.delete_resource_group())
        pass


# HELPER FUNCTIONS ############################################################

def wait_for_op(op, timeout_sec=60):
    """
    Wait for a long-running operation (op) for timeout_sec seconds.

    op is an AzureOperationPoller object.
    """
    time_start = time.time()
    while not op.done():
        op.wait(timeout=timeout_sec)
        print('>> operation status: {0} ({1} sec)'.format(
              op.status(), int(time.time() - time_start)))
    result = op.result()
    if result:
        print('>> operation result: {}'.format(result))


# MAIN ########################################################################

def main(script_args):
    def debug(s):
        """Prints the passed string, with a DEBUG header, if debug is on."""
        if script_args.debug:
            print('[DEBUG]: {}'.format(s))

    """Main script driver."""
    retcode = 0  # PASS
    try:
        deploy_params = {}
        if script_args.param_file:  # Open user-specified params file.
            with open(script_args.param_file) as pfile:
                deploy_params = json.load(pfile)

        atd = AvereTemplateDeploy(
            debug=script_args.debug,
            location=script_args.location,
            deploy_params=deploy_params
        )
        debug('atd = \n{}'.format(atd))

        if not script_args.param_file:
            dparams = {
                **atd.deploy_params,
                'resourceGroup': atd.resource_group
            }
            with open(atd.resource_group + '.params.json', 'w') as pfile:
                json.dump(dparams, pfile)

        print('> Creating resource group: ' + atd.resource_group)
        if not script_args.skip_az_ops:
            rg = atd.create_resource_group()
            debug('Resource Group = {}'.format(rg))

        print('> Deploying template')
        if not script_args.skip_az_ops:
            wait_for_op(atd.deploy())
    except Exception as ex:
        print('\n' + ('><' * 40))
        print('> TEST FAILED')
        print('> EXCEPTION TEXT: {}'.format(ex))
        print(('><' * 40) + '\n')
        retcode = 1  # FAIL
        raise
    except:
        retcode = 2  # FAIL
        raise
    finally:
        if not script_args.skip_rg_cleanup:
            print('> Deleting resource group: ' + atd.resource_group)
            if not script_args.skip_az_ops:
                wait_for_op(atd.delete_resource_group())

        print('> SCRIPT COMPLETE. Resource Group: {} (region: {})'.format(
              atd.resource_group, atd.location))
        print('> RESULT: ' + ('FAIL' if retcode else 'PASS'))
    sys.exit(retcode)


if __name__ == '__main__':
    default_location = 'eastus2'

    arg_parser = argparse.ArgumentParser(
        description='Test template-based Avere vFXT deployment.')

    arg_parser.add_argument('-p', '--param-file', default=None,
        help='Full path to JSON params file. ' +
             'Default: None (generate new params)')
    arg_parser.add_argument('-l', '--location', default=default_location,
        help='Azure location (region short name) to use for deployment. ' +
             'Default: ' + default_location)
    arg_parser.add_argument('-xc', '--skip-rg-cleanup', action='store_true',
        help='Do NOT delete the resource group during cleanup.')
    arg_parser.add_argument('-xo', '--skip-az-ops', action='store_true',
        help='Do NOT actually run any of the Azure operations.')
    arg_parser.add_argument('-d', '--debug', action='store_true',
        help='Turn on script debugging.')
    script_args = arg_parser.parse_args()

    main(script_args)
