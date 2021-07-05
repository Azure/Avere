#!/bin/bash

# report all lines
set -x

# the following variables are set and used in this script
#    PRIVATE_KEY
#    PEER_PUBLIC_KEY
#    PEER_PUBLIC_ADDRESS
#    PEER_ADDRESS_SPACE_CSV
#    TUNNEL_SIDE
#    DUMMY_IP_PREFIX
#    TUNNEL_COUNT
#    BASE_UDP_PORT

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
    apt_get_install 12 5 nfs-kernel-server iotop iperf3 bwm-ng wireguard
}

function configure_wireguard() {
    # add ECMP script for the wireguard interfaces
    /bin/cat <<EOM >/usr/bin/wg-ecmp
#!/bin/bash
set -x

PEER_ADDRESS_SPACE_CSV="$PEER_ADDRESS_SPACE_CSV"
WG_INTERFACES=\$(wg | grep interface | awk '{ print \$2 }')
WGARR=(\$WG_INTERFACES)
WGCOUNT=\${#WGARR[@]}

if [ \$WGCOUNT -gt 0 ] ; then
    for AddressSpace in \$(echo \$PEER_ADDRESS_SPACE_CSV | sed "s/,/ /g"); do
        ecmpCmd="ip route change \$AddressSpace"
        for wg in \$WG_INTERFACES; do
            ecmpCmd="\$ecmpCmd nexthop dev \$wg weight 1"
        done
        \$(\$ecmpCmd)
    done
fi
EOM
    chmod +x /usr/bin/wg-ecmp

    PRIMARY="primary"
    SECONDARY="secondary"
    START_OCTET4=0
    if [ "$TUNNEL_SIDE" == "$SECONDARY" ]; then
        START_OCTET4=1
    fi
    
    for i in $(seq 0 $(expr ${TUNNEL_COUNT} - 1)); do
        WGIFACE="wg$i"
        PORT=$(expr ${BASE_UDP_PORT} + $i)
        BASE_OCTET4=$(expr $i \* 2)
        OCTET4=$(expr ${START_OCTET4} + $i \* 2)
        # avoid printing secrets
        set +x
        /bin/cat <<EOM >/etc/wireguard/${WGIFACE}.conf
[Interface]
PrivateKey = ${PRIVATE_KEY}
ListenPort = ${PORT}
Address = ${DUMMY_IP_PREFIX}.${OCTET4}/31
EOM
        set -x

        # add Table = off, to avoid adding routes on all but first tunnel, per guidance https://blog.muthuraj.in/2020/06/high-throughput-site-to-site-vpn-using.html?m=1
        if [ $i -eq 0 ]; then
            /bin/cat <<EOM >>/etc/wireguard/${WGIFACE}.conf
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE           
EOM
        else
            /bin/cat <<EOM >>/etc/wireguard/${WGIFACE}.conf
Table = off
PostUp = /usr/bin/wg-ecmp
PostDown = /usr/bin/wg-ecmp
EOM
        fi

/bin/cat <<EOM >>/etc/wireguard/${WGIFACE}.conf

[Peer]
PublicKey = ${PEER_PUBLIC_KEY}
AllowedIPs = ${DUMMY_IP_PREFIX}.${BASE_OCTET4}/31,${PEER_ADDRESS_SPACE_CSV}
Endpoint= ${PEER_PUBLIC_ADDRESS}:${PORT}
PersistentKeepalive = 10
EOM
        sudo systemctl enable wg-quick@${WGIFACE}.service
        sudo systemctl daemon-reload
        sudo systemctl start wg-quick@${WGIFACE}
    done

    # enable IP forwarding, and make persistent after boot
    sed -i 's/^#\s*net.ipv4.ip_forward\s*=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sysctl --system
}

function main() {
    touch /opt/install.started

    echo "update linux"
    update_linux

    echo "install wireguard"
    configure_wireguard

    echo "installation complete"
    touch /opt/install.completed
}

main