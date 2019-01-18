import logging
from time import time

import paramiko


def wait_for_op(op, timeout_sec=60):
    """
    Wait for a long-running operation (op) for timeout_sec seconds.

    op is an AzureOperationPoller object.
    """
    log = logging.getLogger("wait_for_op")
    time_start = time()
    while not op.done():
        op.wait(timeout=timeout_sec)
        log.info(">> operation status: {0} ({1} sec)".format(
                 op.status(), int(time() - time_start)))
    result = op.result()
    if result:
        log.info(">> operation result: {}".format(result))
        # log.info(">> result.properties: {}".format(result.properties))
    return result


def create_ssh_client(username, hostname, port=22, password=None):
    """Creates (and returns) an SSHClient. Auth'n is via publickey."""
    ssh_client = paramiko.SSHClient()
    ssh_client.load_system_host_keys()
    ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh_client.connect(
        username=username, hostname=hostname, port=port, password=password
    )
    return ssh_client


def run_averecmd(ssh_client, node_ip, password, method, user='admin', args=''):
    """Run averecmd on the vFXT controller connected via ssh_client."""
    cmd = "averecmd --raw --no-check-certificate " + \
          "--user {0} --password {1} --server {2} {3} {4}".format(
            user, password, node_ip, method, args)
    return eval(run_ssh_command(ssh_client, cmd)['stdout'])


def run_ssh_command(ssh_client, command, ignore_nonzero_rc=False):
    """
    Run a command on the server connected via ssh_client.

    If ignore_nonzero_rc is False, assert when a command fails (i.e., non-zero
    exit/return code).
    """
    log = logging.getLogger("run_ssh_command")

    log.debug("command to run: {}".format(command))
    cmd_stdin, cmd_stdout, cmd_stderr = ssh_client.exec_command(command)

    cmd_rc = cmd_stdout.channel.recv_exit_status()
    log.debug("command exit code: {}".format(cmd_rc))

    cmd_stdout = "".join(cmd_stdout.readlines())
    log.debug("command output (stdout): {}".format(cmd_stdout))

    cmd_stderr = "".join(cmd_stderr.readlines())
    log.debug("command output (stderr): {}".format(cmd_stderr))

    if cmd_rc and not ignore_nonzero_rc:
        log.error(
            '"{}" failed with exit code {}.\n\tSTDOUT: {}\n\tSTDERR: {}'.format(
                command, cmd_rc, cmd_stdout, cmd_stderr)
        )
        assert(0 == cmd_rc)

    return {
        "command": command,
        "stdout": cmd_stdout,
        "stderr": cmd_stderr,
        "rc": cmd_rc
    }


def run_ssh_commands(ssh_client, commands, ignore_nonzero_rc=False):
    """
    Runs a list of commands on the server connected via ssh_client.

    If ex_on_nonzero_rc is True, an Exception is raised if any command fails
    (i.e., non-zero exit code).
    """
    log = logging.getLogger("run_ssh_commands")
    results = []
    for cmd in commands:
        cmd = cmd.strip()
        log.debug("command to run: {}".format(cmd))
        if cmd:  # only run non-empty commands
            results.append(run_ssh_command(ssh_client, cmd, ignore_nonzero_rc))
    return results


def split_ip_range(ip_range):
    """
    split_ip_range will take in an IP address range split by a hyphen
    (e.g., "10.0.0.1-10.0.0.9").

    It will split it to a list of all IPs in that range.
    """
    ip_list = ip_range.split("-")
    ip1 = ip_list[0]
    ip2 = ip_list[1]

    ip1_split = ip1.split(".")
    ip_low = ip1_split[-1]
    ip_hi = ip2.split(".")[-1]

    ip_prefix = ".".join(ip1_split[:-1]) + "."
    return [ip_prefix + str(n) for n in range(int(ip_low), int(ip_hi) + 1)]
