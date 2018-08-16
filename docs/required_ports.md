
# Required ports

The ports listed in this section are used for vFXT inbound and outbound communication. 

Never expose the vFXT or the cluster controller instance directly to the public internet.

## API

| Inbound: | | |
| --- | ---- | --- |
| TCP | 22  | SSH  |
| TCP | 443 | HTTPS|



| Outbound: |     |       |
|----------|-----|-------|
| TCP      | 80  | HTTP  |
| TCP      | 443 | HTTPS |

**[ xxx Ron thinks we don't need 80 - true? xxx ]**
 
## NFS

| Inbound and Outbound  | | |
| --- | --- | ---|
| TCP/UDP | 111  | RPCBIND  |
| TCP/UDP | 2049 | NFS      |
| TCP/UDP | 4045 | NLOCKMGR |
| TCP/UDP | 4046 | MOUNTD   |
| TCP/UDP | 4047 | STATUS   |


**[ xxx exclude SMB for now? xxx ]** 

## SMB/CIFS

| Inbound  |    |    |
| --- | --- | --- | --- |
| TCP     | 445  | SMB      |
| TCP     | 139  | SMB      |
| UDP     | 137  | NETBIOS  |
| UDP     | 138  | NETBIOS  |


| Outbound  |   |   |
| --- | --- | --- |
| TCP/UDP | 53   | DNS      |
| TCP/UDP | 389  | LDAP     |
| TCP     | 686  | LDAPS    |
| TCP/UDP | 88   | Kerberos |
| UDP     | 123  | NTP      |
| TCP     | 445  | SMB      |
| TCP     | 139  | SMB      |
| UDP     | 137  | NetBIOS  |
| UDP     | 138  | NetBIOS  |
