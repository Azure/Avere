import ast
import logging
from time import sleep, time

import paramiko


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
    result = run_ssh_command(ssh_client, cmd)['stdout']
    try:
        return ast.literal_eval(result)
    except (ValueError, SyntaxError):
        return str(result).strip()  # could not eval, return as a string


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


def upload_gsi(averecmd_params):
    """Initiates a GSI collection and upload from the controller."""
    log = logging.getLogger("upload_gsi")
    assert('success' == run_averecmd(**averecmd_params,
                                     method='support.acceptTerms', args='yes'))
    if not run_averecmd(**averecmd_params, method='support.testUpload'):
        log.warning("GSI test upload failed. Proceeding anyway.")

    log.info("Starting normal GSI collection/upload")
    job_id = run_averecmd(**averecmd_params,
                          method='support.executeNormalMode',
                          args='cluster gsimin')
    log.debug("GSI upload job ID: {}".format(job_id))

    timeout_secs = 60 * 10
    time_start = time()
    time_end = time_start + timeout_secs
    gsi_upload_done = False
    while not gsi_upload_done and time() < time_end:
        gsi_upload_done = run_averecmd(**averecmd_params,
                                       method='support.taskIsDone',
                                       args=job_id)
        log.info(">> GSI collection/upload in progress ({} sec)".format(
                 int(time() - time_start)))
        sleep(10)

    if not gsi_upload_done:
        log.error("GSI upload did not complete after {} seconds".format(
                  timeout_secs))
        assert(gsi_upload_done)
    else:
        log.info("GSI upload complete")


def wait_for_op(op, timeout_sec=60, max_polls=60):
    """
    Wait for a long-running operation (op), polling every timeout_sec seconds
    until max_polls polls have completed. Thus maximum wait time is
    (timeout_sec * max_polls) seconds.

    op is an AzureOperationPoller object.
    """
    log = logging.getLogger("wait_for_op")
    time_start = time()
    polls = 1
    while not op.done() and polls <= max_polls:
        op.wait(timeout=timeout_sec)
        log.info(">> operation status: {0} ({1} sec)".format(
                 op.status(), int(time() - time_start)))
        polls += 1
    assert(op.done())
    result = op.result()
    if result:
        log.info(">> operation result: {}".format(result))
        log.info(">> result.properties: {}".format(result.properties))
    return result
