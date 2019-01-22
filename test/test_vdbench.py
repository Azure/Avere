# #!/usr/bin/python3

# """
# Driver for testing Azure ARM template-based deployment of the Avere vFXT.
# """

# import json
# import os
# from time import sleep

# import pytest
# from scp import SCPClient

# from lib import helpers
# from lib.pytest_fixtures import (mnt_nodes, ssh_con, test_vars,  # noqa: F401
#                                  vs_ips)
# from sshtunnel import SSHTunnelForwarder


# class TestVDBench:
#     def test_vdbench_setup(self, mnt_nodes, ssh_con):  # noqa: F811
#         commands = """
#             sudo mkdir -p /nfs/node0/bootstrap
#             cd /nfs/node0/bootstrap
#             sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/bootstrap.vdbench.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/bootstrap.vdbench.sh
#             sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbench50407.zip https://avereimageswestus.blob.core.windows.net/vdbench/vdbench50407.zip
#             sudo curl --retry 5 --retry-delay 5 -o /nfs/node0/bootstrap/vdbenchVerify.sh https://raw.githubusercontent.com/Azure/Avere/master/src/clientapps/vdbench/vdbenchVerify.sh
#             sudo chmod +x /nfs/node0/bootstrap/vdbenchVerify.sh
#             /nfs/node0/bootstrap/vdbenchVerify.sh
#             """.split("\n")
#         helpers.run_ssh_commands(ssh_con, commands)

#     def test_vdbench_deploy(self, test_vars, vs_ips):  # noqa: F811
#         td = test_vars["atd_obj"]
#         with open(os.path.expanduser(r"~/.ssh/id_rsa.pub"), "r") as ssh_pub_f:
#             ssh_pub_key = ssh_pub_f.read()
#         with open("{}/src/client/vmas/azuredeploy.json".format(
#                   os.environ["BUILD_SOURCESDIRECTORY"])) as tfile:
#             td.template = json.load(tfile)
#         orig_params = td.deploy_params.copy()
#         td.deploy_params = {
#             "uniquename": td.deploy_id,
#             "sshKeyData": ssh_pub_key,
#             "virtualNetworkResourceGroup": orig_params["virtualNetworkResourceGroup"],
#             "virtualNetworkName": orig_params["virtualNetworkName"],
#             "virtualNetworkSubnetName": orig_params["virtualNetworkSubnetName"],
#             "nfsCommaSeparatedAddresses": ",".join(vs_ips),
#             "vmCount": 12,
#             "nfsExportPath": "/msazure",
#             "bootstrapScriptPath": "/bootstrap/bootstrap.vdbench.sh",
#         }
#         td.deploy_name = "test_vdbench"
#         deploy_result = helpers.wait_for_op(td.deploy())
#         test_vars["deploy_vd_outputs"] = deploy_result.properties.outputs

#     def test_vdbench_run(self, test_vars):  # noqa: F811
#         node_ip = test_vars["deploy_vd_outputs"]["nodE_0_IP_ADDRESS"]["value"]
#         with SSHTunnelForwarder(
#             test_vars["controller_ip"],
#             ssh_username=test_vars["controller_user"],
#             ssh_pkey=os.path.expanduser(r"~/.ssh/id_rsa"),
#             remote_bind_address=(node_ip, 22),
#         ) as ssh_tunnel:
#             sleep(1)
#             try:
#                 ssh_client = helpers.create_ssh_client(
#                     test_vars["controller_user"],
#                     "127.0.0.1",
#                     ssh_tunnel.local_bind_port,
#                 )
#                 scp_client = SCPClient(ssh_client.get_transport())
#                 try:
#                     scp_client.put(os.path.expanduser(r"~/.ssh/id_rsa"),
#                                    r"~/.ssh/id_rsa")
#                 finally:
#                     scp_client.close()
#                 commands = """
#                     ~/copy_idrsa.sh
#                     cd
#                     ./run_vdbench.sh inmem.conf uniquestring1
#                     """.split("\n")
#                 helpers.run_ssh_commands(ssh_client, commands)
#             finally:
#                 ssh_client.close()


# if __name__ == "__main__":
#     pytest.main()
