#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
pushd jobsubmitter
go build
popd

pushd onpremjobuploader
go build
popd

pushd orchestrator
go build
popd

pushd statscollector
go build
popd


pushd worker
go build
popd
