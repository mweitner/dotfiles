#!/bin/bash

#
# llp_hawkbit_upload.sh - Upload swu image to OTA server (hawkbit)
#
# TODO verify first prototype works for linux-lpo
# Works for LLP base repo, as well as project specific derivates like
# linux-dps, linux-leg4it, linux-smd, ...
#

function print_usage() {
  echo "Usage: MACHINE=<machine> source llp_hawkbit_upload.sh <distro-layer> <image> <device-id>"
  echo " <distro-layer> (optional) := the name of the meta layer of the distro."
  printf "\tDefault: meta-liebherr-distro\n"
  printf "\tThe script evaluates automatically to the location of meta layer.\n"
  echo " <image> (optional) := the image recipe"
  printf "\tDefault: liebherr-image-base\n"
  printf "\tIf distro-layer is defined, the image is mandatory.\n"
  echo " <device-id> (optional) := the hardware device id"
  printf "\tIf distro-layer is defined, the image is mandatory.\n"
  echo " <machine> (mandatory) := the yp machine identifier like imx6sleg-mcg, ..."
}

function contains_arg() {
  if [ $# -lt 2 ]; then
    return 0
  fi
  local wanted="$1"
  shift
  for arg; do
    if [[ "${wanted}" = "${arg}" ]]; then
      return 1
    fi
  done
  return 0
}

function contains_arg_distro_layer() {
  # :return: 1 if distro-layer argument passed, 0 otherwise
  if [ $# -lt 1 ]; then
    return 0 #< guard at least one argument to this function
  fi

  if [[ "$1" = meta-* ]]; then
    echo "found"
    return 1 #< distro-layer argument given
  fi
  return 0
}

if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "[llp_hawkbit_upload] BASH_SOURCE: ${BASH_SOURCE}"
	printf "\\n[llp_hawkbit_upload] Error: This script must to be sourced\\n\\n"
  return 254
fi
bb_machine="$MACHINE"
if [[ -z "$bb_machine" ]]; then
  echo "[llp_hawkbit_upload] Error bb_machine not set"
  print_usage
  return 252 
fi

bb_image_recipe=liebherr-image-base
project_distro_layer="meta-liebherr-distro"
build_root=${BBPATH}
if [[ ! -d "${build_root}" ]];then
  echo "[llp_hawkbit_upload] build_root: ${build_root}"
  printf "\\n[llp_hawkbit_upload] Error: build_root does not exist\\n\\n"
  return 251
fi
echo "args:$#, arg[0]=$0, arg[1]=$1, arg[*]=$@"
if [[ $# -gt 0 ]] && [[ $# -lt 3 ]];then
  if [[ "$1" = "-h" ]]; then
    print_usage
    return 0
  fi 
  contains_arg_distro_layer "$1"
  if [[ $? = 1 ]]; then
    project_distro_layer="$1"
    if [[ $# -lt 2 ]];then
      echo "[llp_hawkbit_upload] Error if <distro-layer> is defined <image> is mandatory"
      return 251
    fi
    bb_image_recipe=$2
  fi
else
  echo "[llp_hawkbit_upload] Error illegal number of params"
  print_usage
  return 251
fi

project_root=$(pwd)
project_root_symlinked=0
if [ ! -d "${project_root}/.repo" ]; then
  echo "[llp_hawkbit_upload] project_root: ${project_root}"
	printf "\\n[llp_hawkbit_upload] Error: Script must be sourced at git-repo project root.\\n\\n"
  return 253
fi
project_name=$(basename "${project_root}")
project_name_symlink=""
if [[ -h "${project_root}" ]]; then
  # as project root is a symlink, read the target file name
  # otherwise, the name would be workspace as the default symlink name for
  # mixed build environment which supports docker and native builds at the
  # same time.
  # Its important to have specific project name instead of a generic name like
  # workspace. See project_name usage at keys folder etc.
  project_root_symlinked=1
  project_name_symlink="${project_name}"
  project_name=$(basename $(readlink -f "${project_root}"))
fi
project_source_root="${project_root}/layers"
echo "Project distro layer: ${project_distro_layer}"
project_distro_layer_path=$(find "${project_source_root}" -iname "${project_distro_layer}" |head -n 1)
if [[ ! -d "${project_distro_layer_path}" ]]; then
  echo "[llp_hawkbit_upload] project_distro_layer_path: ${project_distro_layer_path}"
	printf "\\n[llp_hawkbit_upload:$LINENO] Error: project_distro_layer_path does not exist.\\n\\n"
  return 253
fi

if [[ ${project_root_symlinked} == 1 ]];then
  echo "[llp_hawkbit_upload] Project root (symlink): ${project_root}"
  echo "[llp_hawkbit_upload] Project name (symlink): ${project_name_symlink}"
  echo "[llp_hawkbit_upload] Project root: $(readlink -f ${project_root})"
  echo "[llp_hawkbit_upload] Project name: ${project_name}"
else
  echo "[llp_hawkbit_upload] Project root: ${project_root}"
  echo "[llp_hawkbit_upload] Project name: ${project_name}"
fi
echo "[llp_hawkbit_upload] Project distro root: ${project_distro_layer_path}"

swu_image_file_path="${build_root}/tmp/deploy/images/${bb_machine}/${bb_image_recipe}-${MACHINE}.swu"
if [[ ! -f "${swu_image_file_path}" ]];then
  echo "[llp_hawkbit_upload] swu_image_file_path: ${swu_image_file_path}"
	printf "\\n[llp_hawkbit_upload:$LINENO] Error: swu_image_file_path does not exist.\\n\\n"
  return 253
fi
hbc_tool_config_file_path="${project_root}/tools/hbc/stable-${MACHINE}-env"
if [[ ! -f "${hbc_tool_config_file_path}" ]];then
  echo "[llp_hawkbit_upload] hbc_tool_config_file_path: ${hbc_tool_config_file_path}"
	printf "\\n[llp_hawkbit_upload:$LINENO] Error: hbc_tool_config_file_path does not exist.\\n\\n"
  return 252
fi

pushd "${project_distro_layer_path}"
export VERSION="$(id -un)-$(git describe --tags --dirty)"
popd

export IMAGE="${bb_image_recipe}"
echo "IMAGE=${bb_image_recipe}"
echo "MACHINE=${MACHINE}"
echo "VERSION=${VERSION}"
export ARTIFACT="${swu_image_file_path}"
echo "ARTIFACT=${ARTIFACT}"

pushd "${project_distro_layer_path}/../liebherr/ci/scripts"
. ./hb-device-code-upload.sh "${hbc_tool_config_file_path}"
popd

return 0

