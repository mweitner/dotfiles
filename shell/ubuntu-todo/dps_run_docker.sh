#!/bin/bash

if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "[dps_run_docker] BASH_SOURCE: ${BASH_SOURCE}"
	printf "\\n[dps_run_docker] Error: This script must to be sourced\\n\\n"
  return 254
fi

export YP_PROJECT_DIR=$(pwd)
export YP_BUILD_SSTATE_DIR=/opt/yocto/shared/sstate-cache
export YP_BUILD_DL_DIR=/opt/yocto/shared/downloads

docker run --rm -it \
  -v ${YP_PROJECT_DIR}:/home/yocto \
  -v ${YP_BUILD_DL_DIR}:/opt/yocto/shared/downloads \
  -v ${YP_BUILD_SSTATE_DIR}:/opt/yocto/shared/sstate-cache \
  mweng/yp-build

