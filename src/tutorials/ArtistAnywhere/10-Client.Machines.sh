#!/bin/bash

set -e # Stops execution upon error
set -x # Displays executed commands

export CUEBOT_HOSTS=$RENDER_MANAGER
cueadmin -lh