#!/bin/bash

# report all lines
set -x

function retrycmd_if_failure() {
    retries=$1; wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            return 1
        else
            sleep $wait_sleep
        fi
    done
    echo Executed \"$@\" $i times;
}

function apt_get_install() {
    retries=$1; wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        apt-get install --no-install-recommends -y ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            return 1
        else
            sleep $wait_sleep
            retrycmd_if_failure 12 5 apt-get update
        fi
    done
    echo "completed"
    echo Executed apt-get install --no-install-recommends -y \"$@\" $i times;
}

function update_linux() {
    retrycmd_if_failure 12 5 apt-get update
    apt_get_install 12 5 nfs-kernel-server iotop iperf3 bwm-ng
}

function main() {
    touch /opt/install.started

    echo "update linux"
    update_linux

    echo "installation complete"
    touch /opt/install.completed
}

main