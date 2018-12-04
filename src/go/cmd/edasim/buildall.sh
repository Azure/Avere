#!/bin/bash
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
