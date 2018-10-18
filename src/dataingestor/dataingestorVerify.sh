#!/bin/bash

TARGETDIR=/nfs/node0/bootstrap
DATAINGESTORINSTALL=$TARGETDIR/bootstrap.dataingestor.sh

if [ ! -d "$TARGETDIR" ]; then
    echo "ERROR: directory $TARGETDIR does not exist"
    exit 1
else
    echo "SUCCESS: $TARGETDIR found"
fi

if ! ls $DATAINGESTORINSTALL > /dev/null 2>&1; then
    echo "MISSING: $DATAINGESTORINSTALL.  Please download the install script per instructions."
else
    echo "SUCCESS: $DATAINGESTORINSTALL found"
fi