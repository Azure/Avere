---
title: Avere OS supported encryption standards
date: 09/16/2020
---

# Supported encryption standards for cache products

<!-- adapted from os 5.1.1.2 release notes -->

This document describes the supported encryption standards as of Avere OS 5.1.1.2. These standards apply to the following Microsoft Azure products:

* [Azure FXT Edge Filer](https://azure.microsoft.com/services/fxt-edge-filer/)
* [Avere vFXT for Azure](https://azure.microsoft.com/services/storage/avere-vfxt/)
<!-- * [Azure HPC Cache](https://azure.microsoft.com/services/hpc-cache/) -->

Technology in the products above require the following standards for security. Any system connecting to the products for administrative or infrastructure purposes must meet these standards.

Client machines that mount the cache products do not need to meet all of these requirements, but you should use reasonable efforts to ensure their security.

## TLS standard

* TLS1.2 must be enabled
* SSL V2 and V3 must be disabled

TLS1.0 and TLS1.1 may be used for backward compatibility with private object stores, however it is better to upgrade your private storage to modern security standards. Contact Microsoft Customer Service and Support to learn more.

## Permitted cipher suites

Microsoft security requirements permit the following TLS cipher suites to be negotiated:

* ECDHE-ECDSA-AES128-GCM-SHA256
* ECDHE-ECDSA-AES256-GCM-SHA384
* ECDHE-RSA-AES128-GCM-SHA256
* ECDHE-RSA-AES256-GCM-SHA384
* ECDHE-ECDSA-AES128-SHA256
* ECDHE-ECDSA-AES256-SHA384
* ECDHE-RSA-AES128-SHA256
* ECDHE-RSA-AES256-SHA384

The cluster administrative HTTPS interface (used for the Avere Control Panel web GUI and administrative RPC connections) supports only the above cipher suites and TLS1.2. No other protocols or cipher suites are supported when connecting to the administrative interface.

## SSH server access

These standards apply to the SSH server that is embedded in these products.

The SSH server does not allow remote login as the superuser "root". If remote SSH access is required under the guidance of Microsoft Customer Service and Support, log in as the SSH “admin” user, which has a restricted shell.

The following SSH cipher suites are available on the cluster SSH server. Make sure that any client that uses SSH to connect to the cluster has up-to-date software that meets these standards.

### SSH encryption standards

| Type | Supported values |
|--|--|
| Ciphers | aes256-gcm@openssh.com <br/>aes128-gcm@openssh.com <br/>aes256-ctr <br/>aes128-ctr |
| MACs | hmac-sha2-512-etm@openssh.com <br/>hmac-sha2-256-etm@openssh.com <br/>hmac-sha2-512 </br> hmac-sha2-256 |
| KEX algorithms | ecdh-sha2-nistp521 <br/>ecdh-sha2-nistp384 <br/>ecdh-sha2-nistp256 <br/>diffie-hellman-group-exchange-sha256 |