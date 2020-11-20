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

function main() {
    mkdir -p /opt
    
    if [ "${USE_MARKETPLACE}" = "false" ]; then

        echo "config Linux"
        config_linux

        echo "setup CycleCloud"
        configure_cyclecloud
    fi
    
    echo "installation complete"

    touch /opt/installcycle.complete
}

main
