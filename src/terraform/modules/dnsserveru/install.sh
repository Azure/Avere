#!/bin/bash

# report all lines, and exit on error
set -x
set -e

AZURE_HOME_DIR=/home/$ADMIN_USER_NAME

function retrycmd_if_failure() {
    set +e
    retries=$1; wait_sleep=$2; shift && shift
    for i in $(seq 1 $retries); do
        ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo Executed \"$@\" $i times;
            set -e
            return 1
        else
            sleep $wait_sleep
        fi
    done
    set -e
    echo Executed \"$@\" $i times;
}

function update_linux() {
    retrycmd_if_failure 12 5 apt install -y unbound
}

function configure_unbound() {
    UNBOUND_CONF_FILE=/etc/unbound/unbound.conf
    cp $UNBOUND_CONF_FILE $UNBOUND_CONF_FILE.bak
    cp /opt/unbound.conf $UNBOUND_CONF_FILE

    systemctl restart unbound
    systemctl enable unbound
}

function main() {
    touch /opt/install.started

    echo "update linux"
    update_linux

    echo "configure unbound"
    configure_unbound

    echo "installation complete"
    touch /opt/install.completed
}

main