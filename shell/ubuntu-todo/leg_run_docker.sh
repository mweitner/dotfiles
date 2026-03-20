#!/bin/bash

if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "[leg_run_docker] BASH_SOURCE: ${BASH_SOURCE}"
  printf "\\n[leg_run_docker] Error: This script must to be sourced\\n\\n"
  return 254
fi

yp_srcrev_projects_path=$(pwd)
if [[ $# -eq 1 ]]; then
  if [[ "$1" = "-h" ]]; then
    echo "Usage: source leg_run_docker <srcrev-project-path>"
    echo " <srcrev-project-path> (optional) := srcrev project path"
    return 0
  fi 
  yp_srcrev_projects_path=$1
fi

export YP_PROJECT_DIR=$(pwd)
export YP_BUILD_SSTATE_DIR=$(pwd)/build/sstate-cache
export YP_BUILD_DL_DIR=$(pwd)/downloads
export YP_SRCREV_PROJECTS_DIR=${yp_srcrev_projects_path}

docker run --rm -it \
  -v ${YP_PROJECT_DIR}:/home/yocto \
  -v ${YP_BUILD_DL_DIR}:/opt/yocto/shared/downloads \
  -v ${YP_BUILD_SSTATE_DIR}:/opt/yocto/shared/sstate-cache \
  -v ${YP_SRCREV_PROJECTS_DIR}:/home/yocto/srcrev \
  mweng/yp-build

