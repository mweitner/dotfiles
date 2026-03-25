#!/bin/bash

#
# llp_commands.sh - Provide LLP specific build commands 
#
# MACHINE=imx6sleg-mcg source llp_commands.sh
#
# llp commands:
# - llp_print_kpis
# - llp_get_active_project
# - llp_activate_project
# - llp_upload_swu
#

if [ "${BASH_SOURCE}" = "${0}" ]; then
	printf "\\n[llp_commands] Error: This script must to be sourced\\n\\n"
  return 254
fi

if [ -z "${BBPATH}" ]; then
  echo "[llp_commands] Error: bitbake environment not loaded"
  return 253
fi

function cdn() {
  # cd n levels up
  # param n - level to navigate up
  pushd .
  for ((i=1; i<=$1; i++)); do cd ..; done; pwd;
}

function print_usage() {
  echo "Usage: MACHINE=<machine> source llp_commands <distro-layer> <image> <project>"
  echo " <distro-layer> (optional) := the name of the meta layer of the distro."
  printf "\tDefault: meta-liebherr-distro\n"
  echo " <image> (optional) := the image recipe (default liebherr-image-base)"
  echo " <project> (optional) := the project name (default dev-llp)"
  echo " <machine> (mandatory) := the yp machine identifier like imx6sleg-mcg, ..."
}

function contains_arg_distro_layer() {
  # :return: 1 if distro-layer argument passed, 0 otherwise
  if [ $# -lt 1 ]; then
    return 0 #< guard at least one argument to this function
  fi
  if [[ "$1" = -llp* ]]; then
    return 0 #< guard it is -llp argument -> no distro_layer arg given
  fi

  if [[ "$1" = meta-* ]]; then
    echo "found"
    return 1 #< distro-layer argument given
  fi
  return 0
}

bb_image_recipe=liebherr-image-base
#todo try to extract MACHINE from local.conf or bitbake environment...
bb_machine="$MACHINE"
if [[ -z "$bb_machine" ]]; then
  echo "[llp_commands] Error bb_machine not set"
  print_usage
  return 259
fi

build_root=${BBPATH}
echo "args:$# $0 $1 $2 $3(all: $@)"

project_distro_layer="meta-liebherr-distro"
if [[ $# -gt 0 ]] && [[ $# -lt 3 ]]; then
    if [[ "$1" = "-h" ]]; then
      print_usage
      return 0
    fi

  contains_arg_distro_layer "$1"
  if [[ $? = 1 ]]; then
    project_distro_layer="$1"
  fi
  echo "Project distro layer: ${project_distro_layer}"

  if [[ $# -gt 1 ]];then
    bb_image_recipe=$2
  else
    echo "[llp_commands] Error illegal number of params"
    print_usage
    return 258
  fi
else
  echo "[llp_commands] Error illegal number of params. Must be 3"
  print_usage
  return 257
fi

# replaced old project_root var setting using cdn 1 by pwd
#project_root=$(cdn 1)
project_root=$(pwd)
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
project_source_root="${project_root}/layers"
project_distro_layer_path=$(find "${project_source_root}" -iname "${project_distro_layer}"| head -n 1)
if [[ ! -d "${project_distro_layer_path}" ]]; then
  echo "[llp_init_build] project_distro_layer_path: ${project_distro_layer_path}"
	printf "\\n[llp_init_build] Error: project_distro_layer_path does not exist.\\n\\n"
  return 253
fi

echo "[llp_commands] param count: $#"
echo "[llp_commands] Project root: ${project_root}"
echo "[llp_init_build] Project name: ${project_name}"
echo "[llp_init_build] Project distro root: ${project_distro_layer_path}"
echo "[llp_commands] Build root: ${build_root}"
echo "[llp_commands] Target (machine id): ${bb_machine}"
echo "[llp_commands] Image recipe: ${bb_image_recipe}"

build_images_root="${build_root}/tmp/deploy/images/${bb_machine}"


function llp_print_kpis() {
  kpi_distro_features=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^DISTRO_FEATURES=")
  kpi_image_rootfs_size=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_SIZE=")
  kpi_image_rootfs_extra_space=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_EXTRA_SPACE=")
  kpi_image_rootfs_alignment=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_ROOTFS_ALIGNMENT=")
  kpi_image_overhead_factor=$(MACHINE="${bb_machine}" bitbake -e "${bb_image_recipe}" |grep "^IMAGE_OVERHEAD_FACTOR=")

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
      rm "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic"
    fi
    kpi_size_image_compressed=$(du -Lh "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic.gz")
    gunzip -k "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic.gz" \
      --stdout > "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic"
    kpi_size_image=$(du -Lh "${build_images_root}/${bb_image_recipe}-${bb_machine}.wic")
  fi
  if [[ -f "${build_images_root}/imx-boot" ]];then
    kpi_size_uboot=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/imx-boot")
  elif [[ -f "${build_images_root}/u-boot.img" ]];then
    kpi_size_uboot=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/u-boot.img")
   fi
  
  #provide boot
  kpi_size_kernel=""
  kpi_size_dtb=""
  if [[ -f "${build_images_root}/fitImage" ]];then
    kpi_size_kernel=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/fitImage")
  elif [[ -f "${build_images_root}/Image" ]];then
    kpi_size_kernel=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/Image")
    kpi_size_dtb=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}.dtb")
  else
    echo "[llp_commands] Error no kernel, etc. build"
    return 249
    #exit 249
  fi

  #temporarely handle specific dtb for dc5 display
  # as of uboot environment of legacy system our display has following dtbs
  #
  #fdt_conf=imx6q-display5-tianma-tm121-1280x800.dtb
  #fdt_default=imx6q-display5-tianma-tm070-800x480.dtb
  if [[ -f "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}-tianma-tm121-1280x800.dtb" ]];then
    kpi_size_dtb=$(du -Lh "${build_root}/tmp/deploy/images/${bb_machine}/${bb_machine}-tianma-tm121-1280x800.dtb")
  fi
  
  #provide root
  kpi_size_rootfs=""
  kpi_size_rootfs_targz=$(du -Lh "${build_images_root}/${bb_image_recipe}-${bb_machine}.tar.gz")
  #todo support extracted tar size
  kpi_size_rootfs=$(zcat "${build_images_root}/${bb_image_recipe}-${bb_machine}.tar.gz" | wc -c)
  
  echo "[llp_commands] kpi: "
  
  echo $kpi_distro_features
  echo $kpi_image_rootfs_size |awk '{print "IMAGE_ROOTFS_SIZE: " $1 }'
  echo $kpi_image_rootfs_extra_space |awk '{print "IMAGE_ROOTFS_EXTRA_SPACE: " $1 }'
  echo $kpi_image_rootfs_alignment |awk '{print "IMAGE_ROOTFS_ALIGNMENT: " $1 }'
  echo $kpi_image_overhead_factor |awk '{print "IMAGE_OVERHEAD_FACTOR: " $1 }'
  echo $kpi_size_kernel |awk '{print "kernel: " $1 }'
  echo $kpi_size_dtb |awk '{ print "dtb: " $1 }'
  echo $kpi_size_rootfs_targz |awk '{ print "rootfs.tar.gz: " $1 }'
  echo $kpi_size_rootfs |awk '{ print "rootfs (bytes decimal): " $1 }'
  echo $kpi_size_image |awk '{ print "wic: " $1 }'
  echo $kpi_size_image_compressed |awk '{ print "wic.gz: " $1 }'
  echo $kpi_size_uboot |awk '{ print "uboot: " $1 }'
  echo $kpi_swu_image |awk '{ print "swu: " $1 }'
}

yp_projects_source_root="/opt/yocto/project"
yp_projects_build_root="/opt/yocto/build"
yp_active_project_path="/opt/yocto/workspace"
yp_active_project_build_path="${yp_active_project_path}/build"
yp_active_project_source_path="${yp_active_project_path}/layers"

function llp_list_projects() {
  echo "[llp_list_projects] todo"
}

function llp_get_active_project() {
  echo "[llp_get_active_project]"
  if [[ ! -d "${yp_active_project_path}" ]];then
    echo "[llp_get_active_project] Error yp_active_project_path=${yp_active_project_path} does not exist"
    return 239
  fi
  if [[ ! -h "${yp_active_project_path}" ]];then
    echo "[llp_get_active_project] Error yp_active_project_path=${yp_active_project_path} is not a symlink"
    return 238
  fi
  
  local_project_name=""
  if [[ -h "${yp_active_project_path}" ]]; then
    # as project root is a symlink, read the target file name
    # otherwise, the name would be workspace as the default symlink name for
    # mixed build environment which supports docker and native builds at the
    # same time.
    # Its important to have specific project name instead of a generic name like
    # workspace. See project_name usage at keys folder etc.
    local_project_name=$(basename $(readlink -f "${yp_active_project_path}"))
  fi
  echo "[llp_get_active_project] active project is=${local_project_name}"
}

function llp_activate_project() {
  echo ""
  if [[ -z "$1" ]];then
    echo "[llp_activate_project] Error project name parameter missing"
    return 229
  fi
  local_yp_project_source="${yp_projects_source_root}/$1"
  if [[ ! -d "${local_yp_project_source}" ]];then
    echo "[llp_activate_project] Error project folder=${local_yp_project_source} does not exist"
    return 228
  fi
  local_yp_project_source_external="${local_yp_project_source}/yproot"
  if [[ -d "${local_yp_project_source_external}" ]];then
    echo "[llp_activate_project] External project with yproot sub-folder"
    local_yp_project_source="${local_yp_project_source_external}"
  fi
  echo "[llp_activate_project] Using local_yp_project_source=${local_yp_project_source}"
  local_yp_project_build="${yp_projects_build_root}/$1"
  if [[ ! -d "${local_yp_project_build}" ]];then
    echo "[llp_activate_project] Error project folder=${local_yp_project_build} does not exist"
    return 228
  fi
  echo "[llp_activate_project] Using local_yp_project_build=${local_yp_project_build}"
  echo "[llp_activate_project] activating project: $1"
  
  ln -fns "${local_yp_project_source}" "${yp_active_project_path}"
  if [[ $? != 0 ]];then
    echo "[llp_activate_project] Error failed to symlink ${local_yp_project_source}"
    return 227
  fi

  if [[ ! -d "${local_yp_project_source_external}" ]];then
    ln -fns "${local_yp_project_build}" "${yp_active_project_build_path}"
    if [[ $? != 0 ]];then
      echo "[llp_activate_project] Error failed to symlink ${local_yp_project_build}"
      return 226
    fi
  fi

  return 0
}

function llp_upload_swu() {
  if ! pushd ${project_distro_layer_path};then
    echo "llp_upload_swu] Error could not switch to project_distro_layer_path"
    return 219
  fi

  project_version="${USERNAME}-$(git describe --tags --dirty)"
  echo "[llp_upload_swu] project_version=${project_version}"

  popd
  return 0
}

return 0
