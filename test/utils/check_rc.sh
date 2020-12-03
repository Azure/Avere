#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
#
# Evaluate if a given exit code indicates success (0) or failure.
#
# If failure, output an error message in Azure DevOps Pipelines format.
# Additionally, output the "current task failed" Pipelines string.
#
# PARAMETERS:
#   This script takes two positional parameters:
#     $1: exit code to evaluate (usually called as $?)
#     $2: a string describing the activity whose exit code is being checked
#
# SAMPLE USAGE:
#   * Check the previous command.
#     check_rc.sh $? "resource group creation"
#   * Check the previous command and exit if failed.
#     check_rc.sh $? "resource group creation" || exit 1
#   * Check the previous command. If failed, tag the build and exit.
#     check_rc.sh $? "resource group creation" || (echo "##vso[build.addbuildtag]FAIL RG_create" && exit 1)

if [ "$#" -lt 2 ]; then
    >&2 echo "ERROR: At least two positional parameters are required."
    cat <<EOI
    USAGE: $0 <rc> <activity_msg>
        <rc>: The return (exit) code being checked.
        <activity_msg>: The activity being tested (e.g., "resource group creation")
EOI
    exit 1
fi

rc=$1
shift
activity=$*

nowstr="[$(date -u '+%F %T %Z')]"
if [ "${rc}" -ne 0 ]; then
    >&2 echo "${nowstr}: ERROR: FAILED: ${activity}."
    echo "##vso[task.logissue type=error;]FAILED: ${activity}. See log for details."
    echo "##vso[task.complete result=Failed;]"
    exit ${rc}
else
    echo "${nowstr}: INFO: SUCCESS: ${activity}."
fi
