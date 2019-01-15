import logging
from time import time

import paramiko


def wait_for_op(op, timeout_sec=60):
    """
    Wait for a long-running operation (op) for timeout_sec seconds.

    op is an AzureOperationPoller object.
    """
    log = logging.getLogger('wait_for_op')
    time_start = time()
    while not op.done():
        op.wait(timeout=timeout_sec)
        log.info('>> operation status: {0} ({1} sec)'.format(
                 op.status(), int(time() - time_start)))
    result = op.result()
    if result:
        log.info('>> operation result: {}'.format(result))
        log.info('>> result.properties: {}'.format(result.properties))
    return result


def create_ssh_client(username, hostname, port=22, password=None):
    """Creates (and returns) an SSHClient. Auth'n is via publickey."""
    ssh_client = paramiko.SSHClient()
    ssh_client.load_system_host_keys()
    ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh_client.connect(username=username, hostname=hostname, port=port,
                       password=password)
    return ssh_client


def run_ssh_commands(ssh_client, commands):
    """
    Runs a list of commands on the server connected via ssh_client.

    If sudo_prefix is True, this will add 'sudo' before supplied commands.

    Raises an Exception if any command fails (i.e., non-zero exit code).
    """
    log = logging.getLogger('run_ssh_commands')
    for cmd in commands:
        cmd = cmd.strip()
        if not cmd:  # do not run empty "commands"
            continue

        log.debug('command to run: {}'.format(cmd))
        cmd_stdin, cmd_stdout, cmd_stderr = ssh_client.exec_command(cmd)

        cmd_rc = cmd_stdout.channel.recv_exit_status()
        log.debug('command exit code: {}'.format(cmd_rc))

        cmd_stdout = ''.join(cmd_stdout.readlines())
        log.debug('command output (stdout): {}'.format(cmd_stdout))

        cmd_stderr = ''.join(cmd_stderr.readlines())
        log.debug('command output (stderr): {}'.format(cmd_stderr))

        if cmd_rc:
            raise Exception(
                '"{}" failed with exit code {}.\n\tSTDOUT: {}\n\tSTDERR: {}'
                .format(cmd, cmd_rc, cmd_stdout, cmd_stderr)
            )


def splitList(vserver_ips):
    """
    splitList will take in a string of vservers split by a hyphen

    It will split it to a list of all vserverIps in that range
    """
    x = vserver_ips.split("-")
    ip1 = x[0]
    ip2 = x[1]

    ip1_split = ip1.split(".")
    ip_low = ip1_split[-1]
    ip_hi = ip2.split(".")[-1]

    ip_prefix = ".".join(ip1_split[:-1]) + "."
    vserver_list = [ip_prefix + str(n) for n in range(int(ip_low), int(ip_hi)+1)]
    return vserver_list


if __name__ == '__main__':
    pass
