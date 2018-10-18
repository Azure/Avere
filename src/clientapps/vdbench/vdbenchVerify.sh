#!/bin/bash

TARGETDIR=/nfs/node0/bootstrap
VDBENCHINSTALL=$TARGETDIR/bootstrap.vdbench.sh
VDBENCHSRC="$TARGETDIR/vdbench*.zip"

if [ ! -d "$TARGETDIR" ]; then
    echo "ERROR: directory $TARGETDIR does not exist"
    exit 1
else
    echo "SUCCESS: $TARGETDIR found"
fi

if ! ls $VDBENCHINSTALL > /dev/null 2>&1; then
    echo "MISSING: $VDBENCHINSTALL.  Please download the install script per instructions."
else
    echo "SUCCESS: $VDBENCHINSTALL found"
fi

if ! ls $VDBENCHSRC > /dev/null 2>&1; then
    echo "MISSING: $VDBENCHSRC.  Please download the vdbench zip file from Oracle."
else
    echo "SUCCESS: $VDBENCHSRC found"
fi
