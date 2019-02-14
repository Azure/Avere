#!/usr/bin/python3

"""vFXT cluster health status checks."""

# standard imports
import logging
import os
import sys
from time import sleep

# from requirements.txt
import pytest
from scp import SCPClient
from sshtunnel import SSHTunnelForwarder

# local libraries
from lib.helpers import (create_ssh_client, run_averecmd, run_ssh_commands,
                         upload_gsi)


class TestVfxtClusterStatus:
    """Basic vFXT cluster health tests."""

    def test_basic_fileops(self, mnt_nodes, scp_cli, ssh_con, test_vars):  # noqa: E501, F811
        """
        Quick check of file operations.
        See check_node_basic_fileops.sh for more information.
        """
        if ("storage_account" not in test_vars) or (not test_vars["storage_account"]):
            pytest.skip("no storage account")

        script_name = "check_node_basic_fileops.sh"
        scp_cli.put(
            "{0}/test/{1}".format(test_vars["build_root"], script_name),
            r"~/.",
        )
        commands = """
            chmod +x {0}
            ./{0}
            """.format(script_name).split("\n")
        run_ssh_commands(ssh_con, commands)

    def test_node_health(self, averecmd_params):  # noqa: F811
        """Check that cluster is reporting that all nodes are up."""
        for node in run_averecmd(**averecmd_params, method="node.list"):
            result = run_averecmd(**averecmd_params,
                                  method="node.get", args=node)
            assert result[node]["state"] == "up"

    def test_ha_enabled(self, averecmd_params):  # noqa: F811
        """Check that high-availability (HA) is enabled."""
        result = run_averecmd(**averecmd_params, method="cluster.get")
        assert result["ha"] == "enabled"

    def test_ping_nodes(self, ssh_con, test_vars):  # noqa: F811
        """Ping all of the nodes from the controller."""
        commands = []
        for vs_ip in test_vars["cluster_vs_ips"]:
            commands.append("ping -c 3 {}".format(vs_ip))
        run_ssh_commands(ssh_con, commands)


class TestVfxtSupport:
    """
    Test/support artifact gathering.
    These tests should attempt to run even if deployment has failed.
    """

    def test_for_cores(self, averecmd_params):  # noqa: F811
        """
        Check the cluster for cores. If a core is found, collect/send a GSI.
        """
        log = logging.getLogger("test_for_cores")
        node_cores = run_averecmd(
            **averecmd_params, method="support.listCores", args="cluster"
        )
        cores_found = False
        for cores in node_cores.values():
            if len(cores):
                cores_found = True
                break

        if cores_found:
            log.error("Cores found: {}".format(node_cores))
            upload_gsi(averecmd_params)  # collect/upload a "normal" GSI bundle

        assert(not cores_found)

    def test_artifacts_collect(self, averecmd_params, scp_cli, test_vars):  # noqa: F811, E501
        """
        Collect test artifacts (node logs, rolling trace) from each node.
        Artifacts are stored to local directories.
        """
        log = logging.getLogger("test_collect_artifacts")
        artifacts_dir = "vfxt_artifacts_" + test_vars["atd_obj"].deploy_id
        nodes = run_averecmd(**averecmd_params, method="node.list")
        log.debug("nodes found: {}".format(nodes))
        for node in nodes:
            node_dir = artifacts_dir + "/" + node
            node_dir_log = node_dir + "/log"
            node_dir_trace = node_dir + "/trace"
            log.debug("node_dir_log = {}, node_dir_trace = {}".format(
                node_dir_log, node_dir_trace))

            # make local directories to store downloaded artifacts
            os.makedirs(node_dir_trace, exist_ok=True)
            os.makedirs(node_dir_log, exist_ok=True)

            # get this node's primary cluster IP address
            node_ip = run_averecmd(**averecmd_params,
                                   method="node.get",
                                   args=node)[node]["primaryClusterIP"]["IP"]
            log.debug("tunneling to node {} using IP {}".format(node, node_ip))
            with SSHTunnelForwarder(
                test_vars["public_ip"],
                ssh_username=test_vars["controller_user"],
                ssh_pkey=test_vars["ssh_priv_key"],
                remote_bind_address=(node_ip, 22),
            ) as ssh_tunnel:
                sleep(1)
                try:
                    ssh_client = create_ssh_client(
                        "admin",
                        "127.0.0.1",
                        ssh_tunnel.local_bind_port,
                        password=os.environ["AVERE_ADMIN_PW"],
                    )
                    scp_client = SCPClient(ssh_client.get_transport())
                    try:
                        # list of files from /var/log/ to download
                        var_log_files = ["messages", "xmlrpc.log"]
                        for f in var_log_files:
                            scp_client.get("/var/log/" + f.strip(),
                                           node_dir_log, recursive=True)

                        # assumes that rolling trace was enabled and some trace
                        # data was collected on the nodes
                        scp_client.get("/support/trace/rolling",
                                       node_dir_trace, recursive=True)

                        # TODO: 2019-0125: Turned off for now.
                        # scp_client.get("/support/gsi",
                        #                node_dir, recursive=True)
                        # scp_client.get("/support/cores",
                        #                node_dir, recursive=True)
                    finally:
                        scp_client.close()
                finally:
                    ssh_client.close()


if __name__ == "__main__":
    pytest.main(sys.argv)
