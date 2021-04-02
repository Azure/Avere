#!/bin/bash

# report all lines, and exit on error
set -x

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
    retrycmd_if_failure 12 5 yum -y install wget unzip git nfs-utils tmux unbound
}

function configure_grid() {
    # instructions from https://docs.microsoft.com/en-us/azure/virtual-machines/linux/n-series-driver-setup#install-grid-drivers-on-nv-or-nvv3-series-vms
    NVIDIA_RUN_FILE=/opt/nvidia.run
    # get pre-reqs
    retrycmd_if_failure 12 5 yum -y install gcc
    # unable to do a retry because of the quotes
    yum -y install "kernel-devel-uname-r == $(uname -r)"
    retrycmd_if_failure 12 5 rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    retrycmd_if_failure 12 5 yum -y install dkms
    retrycmd_if_failure 12 5 yum -y install hyperv-daemons
     
    # download
    mkdir -p /opt && curl -L --retry 5 --retry-delay 5 -o $NVIDIA_RUN_FILE  https://go.microsoft.com/fwlink/?linkid=874272

    chmod +x $NVIDIA_RUN_FILE
    $NVIDIA_RUN_FILE -s
}

function configure_gnome() {
    retrycmd_if_failure 12 5 yum -y groups install 'GNOME Desktop'
}

function configure_teradici() {
    # downloads.terradici.com will eventually be deprecated
    retrycmd_if_failure 12 5 yum -y install https://downloads.teradici.com/rhel/teradici-repo-latest.noarch.rpm

    retrycmd_if_failure 12 5 yum -y install epel-release

    retrycmd_if_failure 12 5 yum -y install usb-vhci

    retrycmd_if_failure 12 5 yum -y install pcoip-agent-graphics
}

function configure_teradici_license() {
    # run the following on the machine after the install
    if [[ ! -z "$TERADICI_KEY" ]]; then
        REGISTER_PATH=$(which pcoip-register-host 2> /dev/null)
        if [[ -x "$REGISTER_PATH" ]] ; then
            pcoip-register-host --registration-code=$TERADICI_KEY
        fi
    fi
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
    touch /opt/install.started

    echo "update linux"
    update_linux

    echo "configure GNOME Desktop"
    configure_gnome

    if [[ "true" == "$INSTALL_PCOIP" ]]; then
        echo "configure grid"
        configure_grid

        echo "configure Teradici"
        configure_teradici
    else
        echo "not installing pcoip"
    fi

    echo "configure Teradici License"
    configure_teradici_license

    echo "update search domain"
    update_search_domain

    echo "installation complete"
    touch /opt/install.completed
}

main