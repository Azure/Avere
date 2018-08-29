
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
| TCP      | 443 | HTTPS |

 
## NFS

| Inbound and Outbound  | | |
| --- | --- | ---|
| TCP/UDP | 111  | RPCBIND  |
| TCP/UDP | 2049 | NFS      |
| TCP/UDP | 4045 | NLOCKMGR |
| TCP/UDP | 4046 | MOUNTD   |
| TCP/UDP | 4047 | STATUS   |

