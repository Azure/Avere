#!/usr/bin/python3
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

"""vFXT cluster health status checks."""

# standard imports
import logging
import os
import sys

# from requirements.txt
import pytest
from fabric import Connection
from scp import SCPClient

# local libraries
from lib.helpers import (run_averecmd, run_ssh_commands, upload_gsi)


class TestVfxtClusterStatus:
    """Basic vFXT cluster health tests."""

    def test_basic_fileops(self, mnt_nodes, scp_con, ssh_con, test_vars):  # noqa: E501, F811
        """
        Quick check of file operations.
        See check_node_basic_fileops.sh for more information.
        """
        if ("storage_account" not in test_vars) or (not test_vars["storage_account"]):
            pytest.skip("no storage account")

        script_name = "check_node_basic_fileops.sh"
        scp_con.put(
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

    def test_artifacts_collect(self, averecmd_params, scp_con, test_vars):  # noqa: F811, E501
        """
        Collect test artifacts (node logs, rolling trace) from each node.
        Artifacts are stored to local directories.
        """
        log = logging.getLogger("test_collect_artifacts")
        artifacts_dir = "vfxt_artifacts_" + test_vars["atd_obj"].deploy_id
        os.makedirs(artifacts_dir, exist_ok=True)

        log.debug("Copying logs from controller to {}".format(artifacts_dir))
        for lf in ["vfxt.log", "enablecloudtrace.log", "create_cluster_command.log"]:
            scp_con.get("~/" + lf, artifacts_dir)

        log.debug("Copying SSH keys to the controller")
        scp_con.put(test_vars["ssh_priv_key"], "~/.ssh/.")
        scp_con.put(test_vars["ssh_pub_key"], "~/.ssh/.")

        nodes = run_averecmd(**averecmd_params, method="node.list")
        log.debug("Nodes found: {}".format(nodes))
        last_error = None
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
            log.debug("Tunneling to node {} using IP {}".format(node, node_ip))
            with Connection(test_vars["public_ip"],
                            user=test_vars["controller_user"],
                            connect_kwargs={
                                "key_filename": test_vars["ssh_priv_key"],
                            }).forward_local(local_port=2222,
                                             remote_port=22,
                                             remote_host=node_ip):
                node_c = Connection("127.0.0.1",
                                    user="admin",
                                    port=2222,
                                    connect_kwargs={
                                        "password": os.environ["AVERE_ADMIN_PW"]
                                    })
                node_c.open()
                scp_client = SCPClient(node_c.transport)
                try:
                    # Calls below catch exceptions and report them to the
                    # error log, but then continue. This is because a
                    # failure to collect artifacts on one node should not
                    # prevent collection from other nodes. After collection
                    # has completed, the last exception will be raised.

                    # list of files and directories to download
                    to_collect = [
                        "/var/log/messages",
                        "/var/log/xmlrpc.log",

                        # assumes rolling trace was enabled during deploy
                        "/support/trace/rolling",

                        # TODO: 2019-0219: turned off for now
                        # "/support/gsi",
                        # "/support/cores",
                    ]
                    for tc in to_collect:
                        log.debug("SCP'ing {} from node {} to {}".format(
                                  tc, node, node_dir_log))
                        try:
                            scp_client.get(tc, node_dir_log, recursive=True)
                        except Exception as ex:
                            log.error("({}) Exception caught: {}".format(
                                      node, ex))
                            last_error = ex
                finally:
                    scp_client.close()
            log.debug("Connections to node {} closed".format(node))

        if last_error:
            log.error("See previous error(s) above. Raising last exception.")
            raise last_error


if __name__ == "__main__":
    pytest.main(sys.argv)
