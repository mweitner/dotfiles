#!/bin/bash

#
# llp_provide_netboot.sh - Provide netboot artifacts of current llp project
#
# MACHINE=imx6sleg-mcg llp_provide_netboot.sh
# MACHINE=imx6sleg-mcg source llp_provide_netboot.sh
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

bootstrap_bitbake_env() {
  local env_script oldpwd

  if [[ -n "${BBPATH:-}" ]] && command -v bitbake >/dev/null 2>&1; then
    return 0
  fi

  env_script="${project_root}/layers/poky/oe-init-build-env"
  if [[ ! -f "${env_script}" ]]; then
    echo "[llp_provide_netboot] Error oe-init-build-env not found at ${env_script}"
    return 253
  fi

  if [[ ! -d "${build_root}/conf" ]]; then
    echo "[llp_provide_netboot] Error build root has no conf directory: ${build_root}"
    return 253
  fi

  oldpwd="$PWD"
  # shellcheck disable=SC1090
  . "${env_script}" "${build_root}" >/dev/null
  cd "${oldpwd}" || true
  return 0
}

resolve_first_existing() {
  local candidate
  for candidate in "$@"; do
    if [[ -e "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

function cdn() {
  # cd n levels up
  # param n - level to navigate up
  pushd .
  for ((i=1; i<=$1; i++)); do cd ..; done; pwd;
}

function print_usage() {
  echo "Usage: MACHINE=<machine> llp_provide_netboot.sh <image> <project>"
  echo "   or: MACHINE=<machine> source llp_provide_netboot.sh <image> <project>"
  echo " <image> (optional) := the image recipe (default liebherr-image-base)"
  echo " <project> (optional) := the project name (default dev-llp)"
  echo " <machine> (mandatory) := the yp machine identifier like imx6sleg-mcg, ..."
}

bb_image_recipe=liebherr-image-base
#todo try to extract MACHINE from local.conf or bitbake environment...
bb_machine="$MACHINE"
if [[ -z "$bb_machine" ]]; then
  echo "[llp_provide_netboot] Error bb_machine not set"
  print_usage
  finish 252
fi

# replaced old project_root var setting using cdn 1 by pwd
#project_root=$(cdn 1)
project_root=$(pwd)
# replaced old project_name var setting using static dev-llp with basename ...
#project_name=dev-llp
project_name=$(basename "${project_root}")
if [[ -h "${project_root}" ]]; then
  # as project root is a symlink, read the target file name
  # otherwise, the name would be workspace as the default symlink name for
  # mixed build environment which supports docker and native builds at the
  # same time.
  # Its important to have specific project name instead of a generic name like
  # workspace. See project_name usage at keys folder etc.
  project_name=$(basename $(readlink -f "${project_root}"))
fi
build_root="${BUILD_ROOT:-${BBPATH:-}}"
echo "args:$# $0 $1 $*"
if [[ $# -gt 0 ]]; then
    if [[ "$1" = "-h" ]]; then
      print_usage
      finish 0
    fi

  if [[ $# -eq 1 ]]; then
    bb_image_recipe=$1
  elif [[ $# -eq 2 ]]; then
    bb_image_recipe=$1
    project_name=$2
  else
    echo "[llp_provide_netboot] Error illegal number of params"
    print_usage
    finish 251
  fi
fi

if [[ -z "${build_root}" ]]; then
  if [[ -d "/opt/yocto/build/${project_name}/conf" ]]; then
    build_root="/opt/yocto/build/${project_name}"
  else
    build_root="${project_root}/build-docker"
  fi
fi

if ! bootstrap_bitbake_env; then
  finish $?
fi

build_root="${BBPATH:-${build_root}}"
netboot_root=/opt/netboot
netboot_project_root="${netboot_root}/${project_name}"
netboot_project_root_name=$(basename ${netboot_project_root})
echo "[llp_provide_netboot] param count: $#"
echo "[llp_provide_netboot] Project root: ${project_root}"
echo "[llp_provide_netboot] Build root: ${build_root}"
echo "[llp_provide_netboot] Target (machine id): ${bb_machine}"
echo "[llp_provide_netboot] Image recipe: ${bb_image_recipe}"
echo "[llp_provide_netboot] Netboot project root name: ${netboot_project_root_name}"
echo "[llp_provide_netboot] Netboot root: ${netboot_project_root}"
echo "[llp_provide_netboot] Netboot project root: ${netboot_project_root}"

echo "[llp_provide_netboot] Ensure netboot root layout exists"
sudo mkdir -p "${netboot_root}"
sudo mkdir -p "${netboot_root}/boot" "${netboot_root}/image" "${netboot_root}/root"
sudo mkdir -p "${netboot_project_root}"
sudo mkdir -p "${netboot_project_root}/boot" "${netboot_project_root}/image" "${netboot_project_root}/root"

build_images_root="${build_root}/tmp/deploy/images/${bb_machine}"
nb_boot="${netboot_project_root}/boot/${bb_machine}"
nb_boot_tmp="${netboot_project_root}/boot/${bb_machine}.tmp"
nb_boot_bak="${netboot_project_root}/boot/${bb_machine}.bak"
nb_image="${netboot_project_root}/image/${bb_machine}"
nb_image_tmp="${netboot_project_root}/image/${bb_machine}.tmp"
nb_image_bak="${netboot_project_root}/image/${bb_machine}.bak"
nb_root="${netboot_project_root}/root/${bb_machine}"
nb_root_tmp="${netboot_project_root}/root/${bb_machine}.tmp"
nb_root_bak="${netboot_project_root}/root/${bb_machine}.bak"

wic_gz_path=""
wic_path=""
wic_export_name=""
wic_export_path=""
rootfs_tar_gz_path=""
swu_path=""
#if [[ "${bb_machine}" = "imx6sleg-mcg" ]]; then
#  nb_root="${netboot_project_root}/root/${bb_machine}/UCM-C2-6SOLO"
#  nb_root_tmp="${netboot_project_root}/root/${bb_machine}/UCM-C2-6SOLO.tmp"
#  nb_root_bak="${netboot_project_root}/root/${bb_machine}/UCM-C2-6SOLO.bak"
#fi

kpi_distro_features=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^DISTRO_FEATURES=" || true)
kpi_image_rootfs_size=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_SIZE=" || true)
kpi_image_rootfs_extra_space=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_EXTRA_SPACE=" || true)
kpi_image_rootfs_alignment=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_ALIGNMENT=" || true)
kpi_image_overhead_factor=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_OVERHEAD_FACTOR=" || true)

wic_gz_path=$(resolve_first_existing \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.rootfs.wic.gz" \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic.gz") || true
wic_path=$(resolve_first_existing \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.rootfs.wic" \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic") || true
rootfs_tar_gz_path=$(resolve_first_existing \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.rootfs.tar.gz" \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.tar.gz") || true
swu_path=$(resolve_first_existing \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.rootfs.swu" \
  "${build_images_root}/${bb_image_recipe}-${bb_machine}.swu") || true

if [[ -z "${rootfs_tar_gz_path}" ]]; then
  echo "[llp_provide_netboot] Error rootfs tarball not found for ${bb_image_recipe}/${bb_machine}"
  finish 248
fi
if [[ -z "${wic_gz_path}" && -z "${wic_path}" ]]; then
  echo "[llp_provide_netboot] Error wic image not found for ${bb_image_recipe}/${bb_machine}"
  finish 247
fi

wic_export_name="${bb_image_recipe}-${bb_machine}.wic"
wic_export_path="${nb_image_tmp}/${wic_export_name}"

echo "[llp_provide_netboot] 1/4. create tmp provider"
if [[ ! -d "${nb_boot_tmp}" ]]; then
  sudo mkdir -p "${nb_boot_tmp}"
fi
if [[ ! -d "${nb_image_tmp}" ]]; then
  sudo mkdir -p "${nb_image_tmp}"
fi
if [[ ! -d "${nb_root_tmp}" ]]; then
  sudo mkdir -p "${nb_root_tmp}"
fi

#kpi swu image
kpi_swu_image=""
if [[ -n "${swu_path}" && -f "${swu_path}" ]]; then
  kpi_swu_image=$(du -Lh "${swu_path}")
fi

#provide image
kpi_size_image=""
kpi_size_image_compressed=""
kpi_size_uboot=""
if [[ -n "${wic_gz_path}" && -f "${wic_gz_path}" ]]; then
  if [[ -z "${wic_path}" ]]; then
    wic_path="${wic_gz_path%.gz}"
  fi
  if [[ -f "${wic_path}" ]]; then
    sudo rm -f "${wic_path}"
  fi
  kpi_size_image_compressed=$(du -Lh "${wic_gz_path}")
  gunzip -k "${wic_gz_path}" --stdout > "${wic_path}"
  kpi_size_image=$(du -Lh "${wic_path}")
elif [[ -n "${wic_path}" && -f "${wic_path}" ]]; then
  kpi_size_image=$(du -Lh "${wic_path}")
fi
sudo cp "${wic_path}" "${wic_export_path}"
if [[ -f "${build_images_root}/imx-boot" ]];then
  sudo cp "${build_root}/tmp/deploy/images/${bb_machine}/imx-boot" "${nb_image_tmp}"
  kpi_size_uboot=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/imx-boot")
elif [[ -f "${build_images_root}/u-boot.img" ]];then
  sudo cp "${build_root}/tmp/deploy/images/${bb_machine}/u-boot.img" "${nb_image_tmp}"
  kpi_size_uboot=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/u-boot.img")
 fi

#provide boot
kpi_size_kernel=""
kpi_size_dtb=""
if [[ -f "${build_images_root}/fitImage" ]];then
  sudo cp "${build_root}/tmp/deploy/images/${bb_machine}/fitImage" "${nb_boot_tmp}"
  kpi_size_kernel=$(sudo du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/fitImage")
elif [[ -f "${build_images_root}/Image" ]];then
  sudo cp "${build_root}/tmp/deploy/images/${bb_machine}/Image" "${nb_boot_tmp}"
  sudo cp "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}.dtb" "${nb_boot_tmp}"
  kpi_size_kernel=$(sudo du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/Image")
  kpi_size_dtb=$(sudo du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}.dtb")
else
  echo "[llp_provide_netboot] Error no kernel, etc. build"
  finish 249
fi

#temporarely handle specific dtb for dc5 display
# as of uboot environment of legacy system our display has following dtbs
#
#fdt_conf=imx6q-display5-tianma-tm121-1280x800.dtb
#fdt_default=imx6q-display5-tianma-tm070-800x480.dtb
if [[ -f "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}-tianma-tm121-1280x800.dtb" ]];then
  sudo cp "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}-tianma-tm121-1280x800.dtb" "${nb_boot_tmp}"
  kpi_size_dtb=$(sudo du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}-tianma-tm121-1280x800.dtb")
fi

#provide root
kpi_size_rootfs=""
sudo tar --same-owner -pxzf "${rootfs_tar_gz_path}" \
  -C "${nb_root_tmp}"
kpi_size_rootfs_targz=$(sudo du -Lh "${rootfs_tar_gz_path}")
kpi_size_rootfs=$(sudo du -sLh "${nb_root_tmp}" 2> /dev/null)

echo "[llp_provide_netboot] 2/4. remove old provider backup"
if [[ -d "${nb_boot_bak}" ]]; then
  sudo rm -rf --preserve-root "${nb_boot_bak}"
fi
if [[ -d "${nb_image_bak}" ]]; then
  sudo rm -rf --preserve-root "${nb_image_bak}"
fi
if [[ -d "${nb_root_bak}" ]]; then
  sudo rm -rf --preserve-root "${nb_root_bak}"
fi

echo "[llp_provide_netboot] 3/4. backup current provider"
if [[ -d "${nb_boot}" ]]; then
  sudo mv "${nb_boot}" "${nb_boot_bak}"
fi
if [[ -d "${nb_image}" ]]; then
  sudo mv "${nb_image}" "${nb_image_bak}"
fi
if [[ -d "${nb_root}" ]]; then
  sudo mv "${nb_root}" "${nb_root_bak}"
fi

echo "[llp_provide_netboot] 4/4. activate new provider"
sudo mv "${nb_boot_tmp}" "${nb_boot}"
sudo mv "${nb_image_tmp}" "${nb_image}"
sudo mv "${nb_root_tmp}" "${nb_root}"

echo "[llp_provide_netboot] kpi: "

echo $kpi_distro_features
echo $kpi_image_rootfs_size |awk '{print "IMAGE_ROOTFS_SIZE: " $1 }'
echo $kpi_image_rootfs_extra_space |awk '{print "IMAGE_ROOTFS_EXTRA_SPACE: " $1 }'
echo $kpi_image_rootfs_alignment |awk '{print "IMAGE_ROOTFS_ALIGNMENT: " $1 }'
echo $kpi_image_overhead_factor |awk '{print "IMAGE_OVERHEAD_FACTOR: " $1 }'
echo $kpi_size_kernel |awk '{print "kernel: " $1 }'
echo $kpi_size_dtb |awk '{ print "dtb: " $1 }'
echo $kpi_size_rootfs_targz |awk '{ print "rootfs.tar.gz: " $1 }'
echo $kpi_size_rootfs |awk '{ print "rootfs: " $1 }'
echo $kpi_size_image |awk '{ print "wic: " $1 }'
echo $kpi_size_image_compressed |awk '{ print "wic.gz: " $1 }'
echo $kpi_size_uboot |awk '{ print "uboot: " $1 }'
echo $kpi_swu_image |awk '{ print "swu: " $1 }'


finish 0
