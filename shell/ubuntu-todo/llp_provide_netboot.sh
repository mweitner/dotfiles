#!/bin/bash

#
# llp_provide_netboot.sh - Provide netboot artifacts of current llp project
#
# MACHINE=imx6sleg-mcg source llp_provide_netboot.sh
#

if [ "${BASH_SOURCE}" = "${0}" ]; then
	printf "\\n[llp_provide_netboot] Error: This script must to be sourced\\n\\n"
  #safe to exit as script is not sourced
  #exit 254
  return 254
fi

if [ -z "${BBPATH}" ]; then
  echo "[llp_provide_netboot] Error: bitbake environment not loaded"
  return 253
fi

function cdn() {
  # cd n levels up
  # param n - level to navigate up
  pushd .
  for ((i=1; i<=$1; i++)); do cd ..; done; pwd;
}

function print_usage() {
  echo "Usage: MACHINE=<machine> source llp_provide_netboot <image> <project>"
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
  return 252 
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
build_root=${BBPATH}
echo "args:$# $0 $1 $@"
if [[ $# -gt 0 ]]; then
    if [[ "$1" = "-h" ]]; then
      print_usage
      return 0
    fi 

  if [[ $# -eq 1 ]]; then
    bb_image_recipe=$1
  elif [[ $# -eq 2 ]]; then
    bb_image_recipe=$1
    project_name=$2
  else
    echo "[llp_provide_netboot] Error illegal number of params"
    print_usage
    return 251
  fi
fi
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

if [[ ! -d "${netboot_root}" ]]; then
  echo "[llp_provide_netboot] Error netboot_root does not exist..."
  return 251
fi
if [[ ! -d "${netboot_project_root}" ]]; then
  echo "[llp_provide_netboot] Error netboot_project_root does not exist..."
  return 251
fi

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
#if [[ "${bb_machine}" = "imx6sleg-mcg" ]]; then
#  nb_root="${netboot_project_root}/root/${bb_machine}/UCM-C2-6SOLO"
#  nb_root_tmp="${netboot_project_root}/root/${bb_machine}/UCM-C2-6SOLO.tmp"
#  nb_root_bak="${netboot_project_root}/root/${bb_machine}/UCM-C2-6SOLO.bak"
#fi

kpi_distro_features=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^DISTRO_FEATURES=")
kpi_image_rootfs_size=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_SIZE=")
kpi_image_rootfs_extra_space=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_EXTRA_SPACE=")
kpi_image_rootfs_alignment=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_ALIGNMENT=")
kpi_image_overhead_factor=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_OVERHEAD_FACTOR=")

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
if [[ -f "${build_images_root}/${bb_image_recipe}-${bb_machine}.swu" ]]; then
  kpi_swu_image=$(du -Lh "${build_images_root}/${bb_image_recipe}-${bb_machine}.swu")
fi

#provide image
kpi_size_image=""
kpi_size_image_compressed=""
kpi_size_uboot=""
if [[ -f "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic.gz" ]]; then
  if [[ -f "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic" ]]; then
    sudo rm "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic"
  fi
  kpi_size_image_compressed=$(du -Lh "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic.gz")
  gunzip -k "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic.gz" \
    --stdout > "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic"
  kpi_size_image=$(du -Lh "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic")
fi
sudo cp "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic" "${nb_image_tmp}"
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
  return 249
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
sudo tar --same-owner -pxzf "${build_images_root}/${bb_image_recipe}-${bb_machine}.tar.gz" \
  -C "${nb_root_tmp}"
kpi_size_rootfs_targz=$(sudo du -Lh "${build_images_root}/${bb_image_recipe}-${bb_machine}.tar.gz")
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


return 0
