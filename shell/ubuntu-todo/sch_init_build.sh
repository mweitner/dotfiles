#!/bin/bash

#
# Important this script must be sourced by
# $ source llp_init_build.sh
#
project_root=$(pwd)
echo "[sch_init_build] Project root: ${project_root}"
#export TEMPLATECONF="${project_root}/layers/liebherr/meta-liebherr-distro/conf"

# Example for credentials (no real secrets, just placeholders)
# See .secrets exchange folder for more details
# - .secrets/tmp-cs-credentials.txt
# Example only, not real secrets:
# export LIS_PASSWORD="example"
# export LIS_USER="example"

export WORKSPACE=${project_root}
echo "[sch_init_build] build prepared simply call ./scripts/build.sh <type>"
echo "[sch_init_build] <type> := [debug, testimage prod]"
cd ${WORKSPACE}/sources

