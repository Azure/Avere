#!/bin/bash
set -x

# always source to get go in the path
. $HOME/.profile

# install golang
if ! command -v go &> /dev/null ; then
    GO_DL_FILE=go1.16.6.linux-amd64.tar.gz
    wget --tries=12 --wait=5 https://dl.google.com/go/$GO_DL_FILE
    sudo -E tar -C /usr/local -xzf $GO_DL_FILE
    rm -f $GO_DL_FILE
    echo "export PATH=$PATH:/usr/local/go/bin" >> $HOME/.profile
    . $HOME/.profile
fi

# checkout and build CacheWarmer
cd
RELEASE_DIR=$HOME/release
mkdir -p $RELEASE_DIR
git clone https://github.com/Azure/Avere.git
# build the cache warmer
cd $HOME/Avere/src/go/cmd/cachewarmer/cachewarmer-jobsubmitter
go build
mv cachewarmer-jobsubmitter $RELEASE_DIR/.
cd $HOME/Avere/src/go/cmd/cachewarmer/cachewarmer-manager
go build
mv cachewarmer-manager $RELEASE_DIR/.
cd $HOME/Avere/src/go/cmd/cachewarmer/cachewarmer-worker
go build
mv cachewarmer-worker $RELEASE_DIR/.
cd

# set the path
export CACHEWARMER_MANAGER_PATH=$RELEASE_DIR/cachewarmer-manager
export CACHEWARMER_WORKER_PATH=$RELEASE_DIR/cachewarmer-worker
export CACHEWARMER_JOBSUBMITTER_PATH=$RELEASE_DIR/cachewarmer-jobsubmitter

set +x