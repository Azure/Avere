#!/bin/bash -x

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

function yum_install() {
    retries=$1; wait_sleep=$2; timeout=$3; shift && shift && shift
    for i in $(seq 1 $retries); do
        yum install -y ${@}
        [ $? -eq 0  ] && break || \
        if [ $i -eq $retries ]; then
            echo "failed"
            touch /opt/installcycle.failed
            exit 1
        else
            sleep $wait_sleep
        fi
    done
    echo "completed"
    echo Executed yum install -y \"$@\" $i times;
}

function config_linux() {
    # try for 20 minutes
    yum_install 120 10 180 nfs-utils wget unzip git tmux
}

# export the ephemeral disk as specified by $EXPORT_PATH
function configure_cyclecloud() {
    echo "configure_cyclecloud"
    cat > /etc/yum.repos.d/cyclecloud.repo <<EOF
[cyclecloud]
name=cyclecloud
baseurl=https://packages.microsoft.com/yumrepos/cyclecloud
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

    yum_install 12 10 180 cyclecloud8
}

function install_az_cli() {
    retrycmd_if_failure 12 5 rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
    retrycmd_if_failure 12 5 yum -y install azure-cli
}

function wait_az_login() {
    # wait for RBAC assignments to be applied
    # unfortunately, the RBAC assignments take undetermined time past their associated resource completions to be assigned.
    if ! retrycmd_if_failure 120 5 az login --identity ; then
        echo "MANAGED IDENTITY FAILURE: failed to login after waiting 10 minutes, this is managed identity bug"
        exit 1
    fi
    if ! retrycmd_if_failure 12 5 az account set --subscription $SUBSCRIPTION_ID ; then
        echo "MANAGED IDENTITY FAILURE: failed to set subscription"
        exit 1
    fi
}

function main() {
    mkdir -p /opt
    
    if [ "${USE_MARKETPLACE}" = "false" ]; then

        echo "config Linux"
        config_linux

        echo "setup CycleCloud"
        configure_cyclecloud
    fi

    echo "install az cli"
    install_az_cli

    echo "wait az login"
    wait_az_login
    
    echo "installation complete"

    touch /opt/installcycle.complete
}

main
