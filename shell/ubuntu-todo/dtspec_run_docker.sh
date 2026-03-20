#!/bin/bash

if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "[dtspec_run_docker] BASH_SOURCE: ${BASH_SOURCE}"
	printf "\\n[dtspec_run_docker] Error: This script must to be sourced\\n\\n"
  return 254
fi

export PROJECT_DIR=$(pwd)

docker run --rm -it \
  -v ${PROJECT_DIR}:/home/user \
  mweng/dtspec-doc

