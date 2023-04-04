#!/bin/bash -ex

if [ "${wekaToken}" != "" ]; then
  wekaVersion="4.1.0.77"
  curl https://${wekaToken}@get.prod.weka.io/dist/v1/install/$wekaVersion/$wekaVersion | sh > weka.log
fi
