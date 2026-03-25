#!/bin/bash

#
# llp_activate_netboot.sh - Activates netboot for current target build
#
# MACHINE=imx6sleg-mcg source llp_activate_netboot.sh dev-smd
#
# It simply makes sure symlinks point to proper target build of current
# machine-id (MACHINE).
#

if [ "${BASH_SOURCE}" = "${0}" ]; then
	printf "\\n[llp_activate_netboot] Error: This script must to be sourced\\n\\n"
  #safe to exit as script is not sourced
  #exit 254
  return 254
fi

if [ -z "${BBPATH}" ]; then
  echo "[llp_activate_netboot] Error: bitbake environment not loaded"
  return 253
fi

function cdn() {
  # cd n levels up
  # param n - level to navigate up
  pushd .
  for ((i=1; i<=$1; i++)); do cd ..; done; pwd;
}

function print_usage() {
  echo "Usage: MACHINE=<machine> source llp_activate_netboot <project>"
  echo " <project> (optional) := the project name (default dev-llp)"
  echo " <machine> (mandatory) := the yp machine identifier like imx6sleg-mcg, ..."
}

bb_machine="$MACHINE"
project_root=$(cdn 1)
project_name=dev-llp
build_root=${BBPATH}
if [[ $# -gt 0 ]]; then
    if [[ "$1" = "-h" ]]; then
      print_usage
      return 0
    fi 

  if [[ $# -eq 1 ]]; then
    project_name=$1
  else
    echo "[llp_activate_netboot] Error illegal number of params"
    print_usage
    return 251
  fi
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

if [[ ! -d "${netboot_root}" ]]; then
  echo "[llp_activate_netboot] Error netboot_root does not exist..."
  return 251
fi
if [[ ! -d "${netboot_project_root}" ]]; then
  echo "[llp_activate_netboot] Error netboot_project_root does not exist..."
  return 251
fi

if [[ -z "$bb_machine" ]]; then
  echo "[llp_activate_netboot] Error bb_machine not set"
  return 250
fi
echo "[llp_activate_netboot] Target (machine id): ${bb_machine}"

build_images_root="${build_root}/tmp/deploy/images/${bb_machine}"
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

return 0

