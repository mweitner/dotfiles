#!/bin/bash

#
# llp_backup.sh - backup llp project to be able to do git clean -xdf
#

if [ "${BASH_SOURCE}" = "${0}" ]; then
	printf "\\n[llp_backup] Error: This script must to be sourced\\n\\n"
  return 254
fi

if [ -z "${BBPATH}" ]; then
  echo "[llp_backup] Error: bitbake environment not loaded"
  return 253
fi

function cdn() {
  # cd n levels up
  # param n - level to navigate up
  pushd .
  for ((i=1; i<=$1; i++)); do cd ..; done; pwd;
}

function print_usage() {
  echo "Usage: MACHINE=<machine> source llp_backup <image> <project>"
  echo " <image> (optional) := the image recipe (default liebherr-image-base)"
  echo " <project> (optional) := the project name (default dev-llp)"
  echo " <machine> (mandatory) := the yp machine identifier like imx6sleg-mcg, ..."
}

bb_image_recipe=liebherr-image-base
bb_machine="$MACHINE"
if [[ -z "$bb_machine" ]]; then
  echo "[llp_backup] Error bb_machine not set"
  print_usage()
  return 250
fi
project_name=dev-llp
project_root=$(cdn 1)
build_root=${BBPATH}
echo "args:$# $0 $1 $@"
if [[ $# -gt 1 ]]; then
    if [[ "$1" = "-h" ]]; then
      print_usage
      return 0
    fi 

  if [[ $# -eq 2 ]]; then
    bb_image_recipe=$1
  elif [[ $# -eq 3 ]]; then
    bb_image_recipe=$1
    project_name=$2
  else
    echo "[llp_backup] Error illegal number of params"
    print_usage
    return 251
  fi
fi
llp_system_test_root="${project_root}/layers/liebherr/meta-liebherr-qa/recipes-framework/system-test/files"
llp_backup_dir="${project_root}/backup"
llp_backup_dir_tmp="${project_root}/backup.tmp"
echo "[llp_backup] param count: $#"
echo "[llp_backup] Project root: ${project_root}"
echo "[llp_backup] Build root: ${build_root}"
echo "[llp_backup] Target (machine id): ${bb_machine}"
echo "[llp_backup] Image recipe: ${bb_image_recipe}"
echo "[llp_backup] Backup folder: ${llp_backup_dir}"
echo "[llp_backup] System test root: ${llp_system_test_root}"


if [[ ! -d "${llp_system_test_root}" ]]; then
  echo "[llp_backup] Error system test root does not exist ..."
  return 252
fi
if [[ ! -d "${llp_backup_dir}" ]]; then
  echo "[llp_backup] creating backup folder ${llp_backup_dir} ..."
  mkdir -p "${llp_backup_dir}"
fi

echo "[llp_backup] 1/2. create tmp backup"
if [[ ! -d "${llp_backup_dir_tmp}" ]]; then
  mkdir -p "${llp_backup_dir_tmp}" 
fi

#backup system-test project root 
if [[ -d "${llp_system_test_root}/.idea" ]]; then
  cp -R "${llp_system_test_root}/.idea" "${llp_backup_dir_tmp}"
fi
if [[ -d "${llp_system_test_root}/.run" ]]; then
  cp -R "${llp_system_test_root}/.run" "${llp_backup_dir_tmp}"
fi
if [[ -d "${llp_system_test_root}/config" ]]; then
  cp -R "${llp_system_test_root}/config" "${llp_backup_dir_tmp}"
fi

echo "[llp_backup] 2/2. activate backup"
if [[ -d "${llp_backup_dir}" ]]; then
  rm -rfd --preserve-root "${llp_backup_dir}"
fi
mv "${llp_backup_dir_tmp}" "${llp_backup_dir}"

return 0

