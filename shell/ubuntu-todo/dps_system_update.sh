#!/bin/bash

#
# dps_system_update.sh - adapts the system_update.deb file for firmware update
#

if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "[dps_system_update] BASH_SOURCE: ${BASH_SOURCE}"
	printf "\\n[dps_system_update] Error: This script must to be sourced\\n\\n"
  return 254
fi

project_root=$(pwd)
project_name=$(basename ${project_root})
dps_build_root="${project_root}/build/tmp/deploy/images/imx6sleg-mtg"
dps_system_update_work="${dps_build_root}/system_update_work"
dps_system_update_out="${dps_system_update_work}/system_update"

echo "[dps_system_update] Project root: ${project_root}"
echo "[dps_system_update] Project name: ${project_name}"
if [[ ! -d "${dps_build_root}" ]]; then
  echo "[dps_system_update] Error: Can not find build root"
  echo "[dps_system_update] Make sure this script is executed at project root"
  echo "[dps_system_update]  and bitbake litu3-full is run successfully"
  return 253
fi

function print_usage() {
  echo "Usage: MACHINE=<machine> source dps_system_update"
  echo " <machine> (mandatory) := the yp machine identifier like imx6sleg-mtg, ..."
}

if [[ -d "${dps_system_update_work}" ]]; then
  echo "[dps_system_update] cleanup existing system_update_work folder"
  rm -rfd "${dps_system_update_work}"
fi

if [[ ! -d "${dps_system_update_out}" ]]; then
  mkdir -p "${dps_system_update_out}" 
fi

if [[ ! -f "${dps_build_root}/system_update.deb" ]]; then
  echo "[dps_system_update] Error: Can not find system_update.deb"
  echo "[dps_system_update] Make sure bitbake updatesvc is run successfully"
  return 252
fi

# dpkg-deb -xv
#
#./system_update/
#./system_update/kernel.fit
#./system_update/recovery.fit
#./system_update/rootfs.sqfs
#./system_update/u-boot.imx
# dpkg-deb -xv "${dps_build_root}/system_update.deb" "${dps_build_root}"
#
# ar -xv ...deb --output=...
# tar xvf build/tmp/deploy/images/imx6sleg-mtg/system_update/data.tar.xz \
#   -C build/tmp/deploy/images/imx6sleg-mtg/system_update
#
#./system_update/
#./system_update/kernel.fit
#./system_update/recovery.fit
#./system_update/rootfs.sqfs
#./system_update/u-boot.imx
#ar -x "${dps_build_root}/system_update.deb" --output="${dps_system_update_out}"
#tar xvf "${dps_system_update_out}/data.tar.xz" -C "${dps_system_update_out}"
# important is to use the raw output option -R
dpkg-deb -Rv "${dps_build_root}/system_update.deb" "${dps_system_update_out}"
rm -f "${dps_system_update_out}/system_update/recovery.fit"
rm -f "${dps_system_update_out}/system_update/u-boot.imx"

dpkg-deb --build "${dps_system_update_out}"

return 0

bb_machine="$MACHINE"
if [[ -z "$bb_machine" ]]; then
  echo "[dps_system_update] Error bb_machine not set"
  print_usage()
  return 250
fi

