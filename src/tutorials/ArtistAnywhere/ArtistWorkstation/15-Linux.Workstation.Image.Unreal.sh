#!/bin/bash

set -ex

cd /usr/local/bin

downloadUrl='https://mediasolutions.blob.core.windows.net/bin/Epic'

fileName='UnrealEngine-4.26.0-release.tar.gz'
curl -L -o $fileName $downloadUrl/$fileName
tar -xzf $fileName
