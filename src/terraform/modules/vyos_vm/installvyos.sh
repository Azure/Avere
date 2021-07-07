#!/bin/vbash

# use /bin/vbash as stated in the vyos documentation

# report all lines
set -x

# required to get all the VyOS alias definitions
source /opt/vyatta/etc/functions/script-template

# variables passed in
# ONPREM_VTI_DUMMY_ADDRESS
# VYOS_ADDRESS
# VYOS_BGP_ADDRESS
# CLOUD_ADDRESS
# CLOUD_BGP_ADDRESS
# PRE_SHARED_KEY
# VYOS_ASN
# CLOUD_ASN

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

function configure_vyos() {
    # The below configuration was based on the following VyOS documentation
    # 1. https://docs.vyos.io/en/equuleus/automation/command-scripting.html
    # 2. https://docs.vyos.io/en/equuleus/configexamples/azure-vpn-bgp.html
    echo "enter configure"
    configure
    echo "inside configure"
    set vpn ipsec esp-group AZURE compression 'disable'
    set vpn ipsec esp-group AZURE lifetime '3600'
    set vpn ipsec esp-group AZURE mode 'tunnel'
    set vpn ipsec esp-group AZURE pfs 'dh-group2'
    set vpn ipsec esp-group AZURE proposal 1 encryption 'aes256'
    set vpn ipsec esp-group AZURE proposal 1 hash 'sha1'
    set vpn ipsec ike-group AZURE dead-peer-detection action 'restart'
    set vpn ipsec ike-group AZURE dead-peer-detection interval '15'
    set vpn ipsec ike-group AZURE dead-peer-detection timeout '30'
    set vpn ipsec ike-group AZURE ikev2-reauth 'yes'
    set vpn ipsec ike-group AZURE key-exchange 'ikev2'
    set vpn ipsec ike-group AZURE lifetime '28800'
    set vpn ipsec ike-group AZURE proposal 1 dh-group '2'
    set vpn ipsec ike-group AZURE proposal 1 encryption 'aes256'
    set vpn ipsec ike-group AZURE proposal 1 hash 'sha1'
    set vpn ipsec ipsec-interfaces interface 'eth0'
    set interfaces vti vti1 address $ONPREM_VTI_DUMMY_ADDRESS/32
    set interfaces vti vti1 description 'Azure Tunnel'
    set firewall options interface vti1 adjust-mss 1350
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS authentication id $VYOS_ADDRESS
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS authentication mode 'pre-shared-secret'
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS authentication pre-shared-secret $PRE_SHARED_KEY
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS authentication remote-id $CLOUD_ADDRESS
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS connection-type 'respond'
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS description 'AZURE PRIMARY TUNNEL'
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS ike-group 'AZURE'
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS ikev2-reauth 'inherit'
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS local-address $VYOS_BGP_ADDRESS
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS vti bind 'vti1'
    set vpn ipsec site-to-site peer $CLOUD_ADDRESS vti esp-group 'AZURE'
    set protocols static interface-route $CLOUD_BGP_ADDRESS/32 next-hop-interface vti1
    set protocols bgp $VYOS_ASN neighbor $CLOUD_BGP_ADDRESS remote-as $CLOUD_ASN
    set protocols bgp $VYOS_ASN neighbor $CLOUD_BGP_ADDRESS address-family ipv4-unicast soft-reconfiguration 'inbound'
    set protocols bgp $VYOS_ASN neighbor $CLOUD_BGP_ADDRESS timers holdtime '30'
    set protocols bgp $VYOS_ASN neighbor $CLOUD_BGP_ADDRESS timers keepalive '10'
    set protocols bgp $VYOS_ASN neighbor $CLOUD_BGP_ADDRESS disable-connected-check
    echo "start commit"
    # add some retries for commit as there can be temporary locks on config
    commit || (sleep 10 && commit) || (sleep 10 && commit) || (sleep 10 && commit) || (sleep 10 && commit)
    echo "start save"
    save
    echo "finish save"
    exit
    echo "successful exit"
}

function main() {
    touch /opt/install.started

    echo "configure VyOS VPN Connection"
    configure_vyos

    echo "installation complete"
    touch /opt/install.completed
}

main