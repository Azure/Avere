#!/bin/bash

# Simple file operations check for a vFXT controller that has mounted three
# vFXT nodes. These checks do operations such as writing a file in one mount,
# then checking to see if a different mount sees the file, etc.

set -e
set -x

TOP_DIR_PFX="/nfs/node"

DIR0=${TOP_DIR_PFX}0
DIR1=${TOP_DIR_PFX}1
DIR2=${TOP_DIR_PFX}2

SUBDIRS='lvl_1/lvl.2/lvl-3'
FILE1='file01.txt'
FILE2='file02.md'

# Operations on node0's mount.
cd $DIR0
rm -rf $SUBDIRS || true
mkdir -p $SUBDIRS
cd $SUBDIRS
pwd
dd if=/dev/urandom of=$FILE1 bs=1024 count=512
ls -l $FILE1

# Operations on node1's mount.
mv $FILE1 $DIR1/$SUBDIRS/..
cd $DIR1/$SUBDIRS/..
pwd
ls -l $FILE1
mv $FILE1 $FILE2
ls -l $FILE2
dd if=/dev/urandom of=$FILE2 bs=1024 count=1024
ls -l $FILE2
cp $FILE2 $DIR2/$SUBDIRS
diff $FILE2 $DIR2/$SUBDIRS

# Operations on node2's mount.
cd $DIR2/$SUBDIRS/..
pwd
ls
ls -l $FILE2
cp $FILE2 $FILE1
ls -l $FILE1
chmod -r $FILE2
[[ ! -r $FILE2 ]]
rm $FILE2
[[ ! -e $FILE2 ]]

# Cleanup.
cd $DIR0
rm -rf $SUBDIRS
[[ ! -e $SUBDIRS ]]
