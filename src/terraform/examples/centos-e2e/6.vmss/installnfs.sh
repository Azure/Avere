#!/bin/bash -x
set -x

function yum_install() {
    retries=$1; wait_sleep=$2; timeout=$3; shift && shift && shift
    for i in $(seq 1 $retries); do
        yum install -y ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo "failed"
            touch /opt/installnfs.failed
            exit 1
        else
            sleep $wait_sleep
        fi
    done
    echo "completed"
    echo Executed yum install -y \"$@\" $i times;

    yum install -y nfs-utils
}

function config_linux() {
    # try for 20 minutes
    yum_install 120 10 180 nfs-utils
}

function update_hostname() {
    OCTET3=$((`hostname -i | sed -e 's/^.*\.\([0-9]*\)\.[0-9]*/\1/'  | sed 's/[^0-9]*//g'`))
    OCTET4=$((`hostname -i | sed -e 's/^.*\.\([0-9]*\)/\1/'  | sed 's/[^0-9]*//g'`))

    hostnamectl set-hostname "vm${OCTET3}_${OCTET4}"
}

function update_search_domain() {
    if [[ ! -z "$SEARCH_DOMAIN" ]]; then
        NETWORK_FILE=/etc/sysconfig/network-scripts/ifcfg-eth0
        if grep --quiet "DOMAIN=" $NETWORK_FILE; then
            sed -i 's/^#\s*DOMAIN=/DOMAIN=/g' $NETWORK_FILE
            sed -i "s/^DOMAIN=.*$/DOMAIN=\"${SEARCH_DOMAIN}\"/g"  $NETWORK_FILE
        else
            echo "DOMAIN=\"${SEARCH_DOMAIN}\"" >> $NETWORK_FILE
        fi
        # restart network to take effect
        systemctl restart network
    fi
}

function main() {
    echo "config Linux"
    config_linux

    echo "update hostname"
    update_hostname

    echo "update search domain"
    update_search_domain

    echo "installation complete"

    touch /opt/installnfs.complete
}

main
