#!/usr/bin/python3

"""
Driver for testing Azure ARM template-based deployment of the Avere vFXT.
"""

import logging
import os
from time import sleep

import pytest
from scp import SCPClient

from lib.helpers import (create_ssh_client, run_averecmd, run_ssh_commands,
                         upload_gsi)
from lib.pytest_fixtures import (averecmd_params, mnt_nodes,  # noqa: F401
                                 resource_group, scp_cli, ssh_con, test_vars,
                                 vs_ips)
from sshtunnel import SSHTunnelForwarder


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


class TestVfxtSupport:
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

    def test_artifacts_collect(self, averecmd_params, scp_cli, test_vars):  # noqa: F811
        log = logging.getLogger("test_collect_artifacts")

        artifacts_dir = "vfxt_artifacts_" + test_vars["atd_obj"].deploy_id
        nodes = run_averecmd(**averecmd_params, method="node.list")
        for node in nodes:
            node_dir = artifacts_dir + "/" + node
            node_dir_log = node_dir + "/log"
            node_dir_trace = node_dir + "/trace"

            os.makedirs(node_dir_trace, exist_ok=True)
            os.makedirs(node_dir_log, exist_ok=True)

            node_ip = run_averecmd(**averecmd_params,
                                   method="node.get",
                                   args=node)[node]["primaryClusterIP"]["IP"]
            log.debug("node {}, using IP {}".format(node, node_ip))
            with SSHTunnelForwarder(
                test_vars["controller_ip"],
                ssh_username=test_vars["controller_user"],
                ssh_pkey=os.path.expanduser(r"~/.ssh/id_rsa"),
                remote_bind_address=(node_ip, 22),
            ) as ssh_tunnel:
                sleep(1)
                try:
                    ssh_client = create_ssh_client(
                        "admin",
                        "127.0.0.1",
                        ssh_tunnel.local_bind_port,
                        password=os.environ["AVERE_ADMIN_PW"]
                    )
                    scp_client = SCPClient(ssh_client.get_transport())
                    try:
                        var_log_files = ["messages", "xmlrpc.log"]
                        for f in var_log_files:
                            if not f.strip():
                                continue
                            scp_client.get("/var/log/" + f.strip(),
                                           node_dir_log, recursive=True)
                        scp_client.get("/support/trace/rolling",
                                       node_dir_trace, recursive=True)

                        # TODO: 2019-0125: Turned off until for now.
                        # scp_client.get("/support/gsi",
                        #                node_dir, recursive=True)
                        # scp_client.get("/support/cores",
                        #                node_dir, recursive=True)
                    finally:
                        scp_client.close()
                finally:
                    ssh_client.close()


if __name__ == "__main__":
    pytest.main()
