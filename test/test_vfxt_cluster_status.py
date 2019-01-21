#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

import logging
import os

import pytest

from lib.helpers import run_averecmd, run_ssh_commands, upload_gsi
from lib.pytest_fixtures import (averecmd_params, mnt_nodes,  # noqa: F401
                                 resource_group, scp_cli, ssh_con, test_vars,
                                 vs_ips)


class TestVfxtClusterStatus:
    def test_basic_fileops(self, mnt_nodes, scp_cli, ssh_con):  # noqa: F811
        script_name = "check_node_basic_fileops.sh"
        scp_cli.put("{0}/test/{1}".format(
                       os.environ["BUILD_SOURCESDIRECTORY"], script_name),
                    r"~/.")
        commands = """
            chmod +x {0}
            ./{0}
            """.format(script_name).split("\n")
        run_ssh_commands(ssh_con, commands)

    def test_node_health(self, averecmd_params):  # noqa: F811
        for node in run_averecmd(**averecmd_params, method='node.list'):
            result = run_averecmd(**averecmd_params, method='node.get',
                                  args=node)
            assert(result[node]['state'] == 'up')

    def test_ha_enabled(self, averecmd_params):  # noqa: F811
        result = run_averecmd(**averecmd_params, method='cluster.get')
        assert(result['ha'] == 'enabled')

    def test_ping_nodes(self, ssh_con, vs_ips):  # noqa: F811
        commands = []
        for vs_ip in vs_ips:
            commands.append("ping -c 3 {}".format(vs_ip))
        run_ssh_commands(ssh_con, commands)

    def test_for_cores(self, averecmd_params):  # noqa: F811
        log = logging.getLogger("test_for_cores")
        node_cores = run_averecmd(**averecmd_params,
                                  method='support.listCores',
                                  args='cluster')
        cores_found = False
        for cores in node_cores.values():
            if len(cores):
                cores_found = True
                break

        if cores_found:
            log.error("Cores found: {}".format(node_cores))
            upload_gsi(averecmd_params)  # collect/upload a "normal" GSI bundle

        assert(not cores_found)


if __name__ == "__main__":
    pytest.main()
