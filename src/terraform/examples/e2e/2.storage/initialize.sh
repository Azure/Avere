#!/bin/bash -ex

binDirectory="/usr/local/bin"
cd $binDirectory

%{ if wekaToken != "" }
  curl -L https://${wekaToken}@get.prod.weka.io/dist/v1/install/${wekaVersion}/${wekaVersion}
%{ endif }
