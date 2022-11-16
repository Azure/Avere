#!/bin/bash -ex

deadlineworker -shutdown
deadlinecommand -DeleteSlave $(hostname)