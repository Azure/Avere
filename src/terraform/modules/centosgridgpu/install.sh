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
    NVIDIA_RUN_FILE=/opt/nvidia.run
    # get pre-reqs
    retrycmd_if_failure 12 5 yum -y install gcc
    retrycmd_if_failure 12 5 yum -y install kernel-devel

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

    # run the following on the machine after the install
    # pcoip-register-host --registration-code=$teradiciLicenseKey
}

function main() {
    touch /opt/install.started

    echo "update linux"
    update_linux

    echo "configure grid"
    configure_grid

    echo "configure GNOME Desktop"
    configure_gnome

    echo "configure Teradici"
    configure_teradici

    echo "installation complete"
    touch /opt/install.completed
}

main