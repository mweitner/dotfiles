#!/bin/bash

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "[dtspec_run_docker] BASH_SOURCE: ${BASH_SOURCE[0]}"
	printf "\\n[dtspec_run_docker] Error: This script must to be sourced\\n\\n"
  return 254
fi

PROJECT_DIR=$(pwd)
export PROJECT_DIR

docker run --rm -it \
  -v "${PROJECT_DIR}":/home/user \
  mweng/dtspec-doc
