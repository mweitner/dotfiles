#!/bin/bash

export YP_PROJECT_DIR=$(pwd)
export YP_BUILD_SSTATE_DIR=/opt/yocto/shared/sstate-cache
export YP_BUILD_DL_DIR=/opt/yocto/shared/downloads

docker run --rm -it \
  -v ${YP_PROJECT_DIR}:/home/yocto \
  -v ${YP_BUILD_DL_DIR}:/opt/yocto/shared/downloads \
  -v ${YP_BUILD_SSTATE_DIR}:/opt/yocto/shared/sstate-cache \
  mweng/yp-build

