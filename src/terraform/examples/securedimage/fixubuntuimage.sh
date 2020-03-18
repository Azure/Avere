#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.

set -x

function fix_mod_probe() {
    FILENAME=/etc/modprobe.d/blacklist-nouveau.conf
    /bin/cat <<EOM >$FILENAME
# CLOUD_IMG: This file was created/modified by the Cloud Image build process
# Eliminate conflicts with nVIDIA drivers for GPU instances using stock kernels
blacklist nouveau
options nouveau modeset=0
EOM
}

function fix_cloud_config() {
    rm -f /etc/cloud/ds-identify.cfg
    rm -f /etc/cloud/cloud.cfg.d/50-curtin-networking.cfg
    rm -f /etc/cloud/cloud.cfg.d/curtin-preserve-sources.cfg

    FILENAME=/etc/cloud/cloud.cfg.d/10-azure-kvp.cfg
    /bin/cat <<EOM >$FILENAME
# CLOUD_IMG: This file was created/modified by the Cloud Image build process
reporting:
  logging:
    type: log
  telemetry:
    type: hyperv
EOM
    
    FILENAME=/etc/cloud/cloud.cfg.d/90_dpkg.cfg
    /bin/cat <<EOM >$FILENAME
# to update this file, run dpkg-reconfigure cloud-init
datasource_list: [ Azure ]
EOM
    FILENAME=/etc/cloud/cloud.cfg.d/90-azure.cfg
    /bin/cat <<EOM >$FILENAME
# CLOUD_IMG: This file was created/modified by the Cloud Image build process
system_info:
   package_mirrors:
     - arches: [i386, amd64]
       failsafe:
         primary: http://archive.ubuntu.com/ubuntu
         security: http://security.ubuntu.com/ubuntu
       search:
         primary:
           - http://azure.archive.ubuntu.com/ubuntu/
         security: []
     - arches: [armhf, armel, default]
       failsafe:
         primary: http://ports.ubuntu.com/ubuntu-ports
         security: http://ports.ubuntu.com/ubuntu-ports
EOM
    # after systemd changes
}

function fix_cloud_init() {
    mkdir -p /lib/systemd/system/cloud-init-local.service.d
    FILENAME=/lib/systemd/system/cloud-init-local.service.d/50-azure-clear-persistent-obj-pkl.conf
    /bin/cat <<EOM >$FILENAME
[Service]
ExecStartPre=-/bin/sh -xc 'if [ -e /var/lib/cloud/instance/obj.pkl ]; then echo "cleaning persistent cloud-init object"; rm /var/lib/cloud/instance/obj.pkl; fi; exit 0'
EOM
    systemctl daemon-reload
}

function fix_grub() {
    FILENAME=/etc/default/grub.d/50-cloudimg-settings.cfg
    /bin/cat <<EOM >$FILENAME
# Windows Azure specific grub settings
# CLOUD_IMG: This file was created/modified by the Cloud Image build process

# Set the default commandline
GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0 earlyprintk=ttyS0 rootdelay=300"

# Set the grub console type
GRUB_TERMINAL=serial

# Set the serial command
GRUB_SERIAL_COMMAND="serial --speed=9600 --unit=0 --word=8 --parity=no --stop=1"

# Set the recordfail timeout
GRUB_RECORDFAIL_TIMEOUT=0

# Do not wait on grub prompt
GRUB_TIMEOUT=0
EOM

    FILENAME=/etc/default/grub
    /bin/cat <<EOM >$FILENAME
# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

# Set the default commandline
GRUB_CMDLINE_LINUX_DEFAULT="console=tty1 console=ttyS0 earlyprintk=ttyS0 rootdelay=300"

# Set the grub console type
GRUB_TERMINAL=serial

# Set the serial command
GRUB_SERIAL_COMMAND="serial --speed=9600 --unit=0 --word=8 --parity=no --stop=1"

# Set the recordfail timeout
GRUB_RECORDFAIL_TIMEOUT=0

# Do not wait on grub prompt
GRUB_TIMEOUT=0

GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_DISTRIBUTOR=\`lsb_release -i -s 2> /dev/null || echo Debian\`

# Uncomment to enable BadRAM filtering, modify to suit your needs
# This works with Linux (no patch required) and with any kernel that obtains
# the memory map information from GRUB (GNU Mach, kernel of FreeBSD ...)
#GRUB_BADRAM="0x01234567,0xfefefefe,0x89abcdef,0xefefefef"

# Uncomment to disable graphical terminal (grub-pc only)
#GRUB_TERMINAL=console

# The resolution used on graphical terminal
# note that you can use only modes which your graphic card supports via VBE
# you can see them in real GRUB with the command \`vbeinfo\`
#GRUB_GFXMODE=640x480

# Uncomment if you don't want GRUB to pass "root=UUID=xxx" parameter to Linux
#GRUB_DISABLE_LINUX_UUID=true

# Uncomment to disable generation of recovery mode menu entries
#GRUB_DISABLE_RECOVERY="true"

# Uncomment to get a beep at grub start
#GRUB_INIT_TUNE="480 440 1"
EOM
    update-grub
}

function fix_initramfs() {
    FILENAME=/etc/initramfs-tools/modules
    /bin/cat <<EOM >$FILENAME
# List of modules that you want to include in your initramfs.
# They will be loaded at boot time in the order below.
#
# Syntax:  module_name [args ...]
#
# You must run update-initramfs(8) to effect this change.
#
# Examples:
#
# raid1
# sd_mod

# CLOUD_IMG: This file was created/modified by the Cloud Image build process
# This fix is important on virtual machines, because when hyperv_fb.ko is
# missing, the "setfont" stage for the console (part of the boot process)
# will add 2-4 minutes to initialization on Ubuntu. Apparently this operation
# does a lot of work with the emulated device and its generic VGA driver.
hyperv_fb
EOM
}

function main() {
    fix_mod_probe
    fix_cloud_config
    fix_initramfs
    fix_grub
    fix_cloud_init
}

main