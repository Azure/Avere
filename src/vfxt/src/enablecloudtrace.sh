#!/bin/bash

###########################################################
#
# Watch vfxt.log and enable cloud trace after the
# management IP is received, and disable cloud trace after
# the script has finished.  The purpose of cloud trace is
# for additional debugging information during installation.
#
# Ensure completion by stopping if the vfxt.log file does
# not show up or if the installation script stops, and
# vfxt.log stops being updated.
#
###########################################################

# report all lines, and exit on error
set -x

# this script will handle all its errors, so don't set -e
# set -e

AZURE_HOME_DIR=/home/$CONTROLLER_ADMIN_USER_NAME
VFXT_LOG_FILE=$AZURE_HOME_DIR/vfxt.log
WAIT_SECONDS=300
RPC_ENABLE="enable"
RPC_DISABLE="disable"
RPC_ENABLE_2="enable"

function sendRPC() {
    set +x
    ipaddress=$1; action=$2

    AVERECMD="averecmd --raw --no-check-certificate --user admin --password $ADMIN_PASSWORD --server $ipaddress"
    if [ "$action" == "$RPC_ENABLE" ] ; then
        echo "send 'support.acceptTerms yes' to ${ipaddress}"
        $AVERECMD support.acceptTerms yes
        result=$?

        echo "send ${action} to ${ipaddress}"
        $AVERECMD support.modify "{'traceLevel': '0x4000000000000', 'rollingTrace': 'yes', 'statsMonitor': 'yes', 'memoryDebugging': 'yes'}"
        result=$((result+$?))
    elif [ "$action" == "$RPC_DISABLE" ] ; then
        echo "send ${action} to ${ipaddress}"
        $AVERECMD support.modify "{'traceLevel': '0x1', 'rollingTrace': 'no', 'statsMonitor': 'no', 'memoryDebugging': 'no'}"
        result=$?
    elif [ "$action" == "$RPC_ENABLE_2" ] ; then
        echo "send 'support.acceptTerms yes' to ${ipaddress}"
        $AVERECMD support.acceptTerms yes
        result=$?

        echo "send ${action} to ${ipaddress}"
        $AVERECMD support.modify "{'traceLevel': '0xa00000000100', 'rollingTrace': 'yes', 'statsMonitor': 'yes', 'memoryDebugging': 'yes'}"
        result=$((result+$?))
    else
        echo "ERROR: bad action"
        result=1
    fi

    set -x
    return $result
}

function check_halted_vfxt() {
    now=$(date +%s)
    filemtime=$(stat -c %Y $VFXT_LOG_FILE)
    difference=$(($now-$filemtime))
    if [ "$difference" -gt "$WAIT_SECONDS" ] ; then
        echo "FATAL: the log file ${VFXT_LOG_FILE} has halted"
        exit 1
    fi
}

function wait_vfxt_log() {
    counter=0
    while [ ! -f $VFXT_LOG_FILE ]; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $WAIT_SECONDS ]; then
            echo "file '${VFXT_LOG_FILE}' did not appear after ${WAIT_SECONDS} seconds"
            exit 1
        fi
    done
}

function wait_management_ip() {
    while :
    do
        ipaddress=$(egrep "^address=([0-9]{1,3}\.){3}[0-9]{1,3}" ${VFXT_LOG_FILE} | awk '{match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print ip}')
        if [ "${#ipaddress}" -gt "0" ]
        then
            echo "${ipaddress}"
            break
        fi
        check_halted_vfxt
        sleep 1
    done
}

function wait_complete_message() {
    while :
    do
        if grep --quiet "vfxt:INFO - Complete" ${VFXT_LOG_FILE}; then
            echo "vfxt has completed installation"
            break
        elif grep --quiet "vfxt:ERROR - Failed to create cluster" ${VFXT_LOG_FILE}; then
            echo "vfxt installation failed"
            break
        fi
        check_halted_vfxt
        sleep 1
    done
}

function enable_cloud_trace() {
    ipaddress=$1
    echo "trying to enable cloud trace "

    while :
    do
        # retry forever until we reach the mgmt ip or the vfxt.log stops
        if sendRPC $ipaddress $RPC_ENABLE ; then
            echo "sendRPC success"
            break
        fi

        check_halted_vfxt
        sleep 5
    done

    echo "cloud trace enabled"
}


function enable_cloud_node_trace() {
    ipaddress=$1
    echo "trying to enable cloud node trace "

    while :
    do
        # retry forever until we reach the mgmt ip or the vfxt.log stops
        if sendRPC $ipaddress $RPC_ENABLE_2 ; then
            echo "sendRPC success"
            break
        fi

        check_halted_vfxt
        sleep 5
    done

    echo "cloud node trace enabled"
}

function disable_cloud_trace() {
    ipaddress=$1
    echo "trying to disable cloud trace "

    while :
    do
        # retry forever until we reach the mgmt ip or the vfxt.log stops
        if sendRPC $ipaddress $RPC_DISABLE ; then
            echo "sendRPC success"
            break
        fi

        check_halted_vfxt
        sleep 5
    done

    echo "cloud trace disabled"
}

function main() {
    echo "wait for vfxt log file to appear"
    wait_vfxt_log

    MGMT_IP=$(wait_management_ip)

    enable_cloud_trace $MGMT_IP

    wait_complete_message

    disable_cloud_trace $MGMT_IP

    enable_cloud_node_trace $MGMT_IP
}

main