#!/bin/bash

#
# llp_activate_netboot.sh - Activates netboot for current target build
#
# MACHINE=imx6sleg-mcg llp_activate_netboot.sh dev-smd
# MACHINE=imx6sleg-mcg source llp_activate_netboot.sh dev-smd
#
# It simply makes sure symlinks point to proper target build of current
# machine-id (MACHINE).
#

is_sourced=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  is_sourced=1
fi

finish() {
  local rc="$1"
  if [[ ${is_sourced} -eq 1 ]]; then
    return "${rc}"
  fi
  exit "${rc}"
}

function cdn() {
  # cd n levels up
  # param n - level to navigate up
  pushd .
  for ((i=1; i<=$1; i++)); do cd ..; done; pwd;
}

function print_usage() {
  echo "Usage: MACHINE=<machine> llp_activate_netboot.sh <project>"
  echo "   or: MACHINE=<machine> source llp_activate_netboot.sh <project>"
  echo " <project> (optional) := the project name (default dev-llp)"
  echo " <machine> (mandatory) := the yp machine identifier like imx6sleg-mcg, ..."
}

bb_machine="$MACHINE"
project_root=$(pwd)
if [[ -h "${project_root}" ]]; then
  project_root=$(readlink -f "${project_root}")
fi
project_name=dev-llp
build_root="${BUILD_ROOT:-${BBPATH:-}}"
if [[ $# -gt 0 ]]; then
    if [[ "$1" = "-h" ]]; then
      print_usage
      finish 0
    fi

  if [[ $# -eq 1 ]]; then
    project_name=$1
  else
    echo "[llp_activate_netboot] Error illegal number of params"
    print_usage
    finish 251
  fi
fi

if [[ -z "${build_root}" ]]; then
  build_root="/opt/yocto/build/${project_name}"
fi
netboot_root=/opt/netboot
netboot_project_root="${netboot_root}/${project_name}"
netboot_project_root_name=$(basename ${netboot_project_root})
echo "[llp_activate_netboot] param count: $#"
echo "[llp_activate_netboot] Project root: ${project_root}"
echo "[llp_activate_netboot] Build root: ${build_root}"
echo "[llp_activate_netboot] Netboot root: ${netboot_project_root}"
echo "[llp_activate_netboot] Netboot project root: ${netboot_project_root}"
echo "[llp_activate_netboot] Netboot project root name: ${netboot_project_root_name}"

echo "[llp_activate_netboot] Ensure netboot root layout exists"
sudo mkdir -p "${netboot_root}"
sudo mkdir -p "${netboot_root}/boot" "${netboot_root}/image" "${netboot_root}/root"
sudo mkdir -p "${netboot_project_root}"
sudo mkdir -p "${netboot_project_root}/boot" "${netboot_project_root}/image" "${netboot_project_root}/root"

if [[ -z "$bb_machine" ]]; then
  echo "[llp_activate_netboot] Error bb_machine not set"
  finish 250
fi
echo "[llp_activate_netboot] Target (machine id): ${bb_machine}"

nb_boot="${netboot_root}/boot/${bb_machine}"
nb_project_boot="${netboot_project_root}/boot/${bb_machine}"
nb_image="${netboot_root}/image/${bb_machine}"
nb_project_image="${netboot_project_root}/image/${bb_machine}"
nb_root="${netboot_root}/root/${bb_machine}"
nb_project_root="${netboot_project_root}/root/${bb_machine}"

echo "[llp_activate_netboot] 1/1. Create current symlinks"
echo "${nb_project_boot}"
sudo rm -f "${nb_boot}"
sudo ln -s "${nb_project_boot}" "${nb_boot}"
echo "${nb_project_image}"
sudo rm -f "${nb_image}"
sudo ln -s "${nb_project_image}" "${nb_image}"
echo "${nb_project_root}"
sudo rm -f "${nb_root}"
sudo ln -s "${nb_project_root}" "${nb_root}"

finish 0
