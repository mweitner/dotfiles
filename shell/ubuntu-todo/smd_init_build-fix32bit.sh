#!/bin/bash

#
# llp_init_build.sh - Init the llp yp build environment
#

if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "[llp_init_build] BASH_SOURCE: ${BASH_SOURCE}"
	printf "\\n[llp_init_build] Error: This script must to be sourced\\n\\n"
  return 254
fi

project_root=$(pwd)
project_name=$(basename ${project_root})
llp_distro_root="${project_root}/layers/liebherr/meta-liebherr-distro"
smd_distro_root="${project_root}/layers/meta-lmt-smd"

echo "[llp_init_build] Project root: ${project_root}"
echo "[llp_init_build] Project name: ${project_name}"
if [[ ! -d "${llp_distro_root}" ]]; then
  echo "[llp_init_build] Error: Can not find llp distro root"
  echo "[llp_init_build] Make sure this script is executed at project root"
  return 253
fi
export TEMPLATECONF="${smd_distro_root}/conf"

if [[ -d "${project_root}/build/conf" ]]; then
  echo "[llp_init_build] Yocto config exists, removing it ..."
  rm -rd "${project_root}/build/conf"
fi

. ./layers/poky/oe-init-build-env

echo "[llp_init_build] Appending development stuff to local.conf"
# current working dir is ./build
cat <<EOT >> "${project_root}/build/conf/local.conf"

#
# additional project specific stuff no checked into repo
#

#
# sync with algo development LMT
#python == 3.9.12
#pandas == 1.4.2
#numpy == 1.21.5
#scikit-learn == 1.0.2
#scipy == 1.7.3
#

#PREFERRED_VERSION:python3-numpy = "\${bb.utils.contains('SMD_FEATURES', 'smd-pythons310-support', '1.21.2', d)}"
PREFERRED_VERSION:python3-pandas = "\${bb.utils.contains('SMD_FEATURES', 'smd-pythons310-support', '1.4.2', d)}"
#BBMASK:append = " \\
#    poky/meta/recipes-devtools/python/python3-numpy_1.22.3.bb \\
#    meta-openembedded/meta-python/recipes-devtools/python/python3-pandas_1.4.2.bb \\
#"
BBMASK:append = " \\
    meta-python3-compat/recipes-devtools/python3-numpy_1.21.2/python3-numpy_1.21.2.bb \\
    meta-python3-compat/recipes-devtools/python3-numpy_1.22.3/python3-numpy_1.21.2.bb \\
    meta-python3-compat/recipes-devtools/python3-numpy_1.23.3/python3-numpy_1.23.3.bb \\
    meta-python3-compat/recipes-devtools/python3/python3-cython_0.29.32.bb \\
    meta-python3-compat/recipes-devtools/python3/python3-pandas_1.3.3.bb \\
    meta-python3-compat/recipes-devtools/python3/python3-pandas_1.5.1.bb \\
"

#
# Python 3.8 specify preferred versions for [cython, numpy, scipy, lapack]
# and mask their newer versions
#
# mask cython v0.29.28 as it is not building
# mask numpy v1.22.3 as it is not building
# version for lapack is v3.9.0 but v3.10.0 works also with scipy v1.5.4
#
PREFERRED_VERSION:python3.8-cython = "\${bb.utils.contains('SMD_FEATURES', 'smd-python38-support', '0.29.24', d)}"
PREFERRED_VERSION:python3.8-numpy = "\${bb.utils.contains('SMD_FEATURES', 'smd-pythons38-support', '1.21.2', d)}"
PREFERRED_VERSION:python3.8-scipy = "\${bb.utils.contains('SMD_FEATURES', 'smd-python38-support', '1.5.4', '', d)}" 
PREFERRED_VERSION:lapack = "\${bb.utils.contains('SMD_FEATURES', 'smd-python38-support', '3.10.0', '', d)}"
#BBMASK does not support regular expression as bb.utils.contains
#BBMASK:append = "\${bb.utils.contains('SMD_FEATURES', 'smd-python38-suppport', '\${PYTHON38_BBMASK}', '', d)}"
BBMASK:append = " \\
    meta-python3-compat/recipes-devtools/python-cython_0.29.28/python3.8-cython_0.29.28.bb \\
    meta-python3-compat/recipes-devtools/python3-numpy_1.22.3/python3.8-numpy_1.22.3.bb \\
    meta-python3-compat/recipes-scipy/python/python3.8-scipy_1.8.1.bb \\
    meta-python3-compat/recipes-devtools/lapack/lapack_3.9.0.bb \\
    meta-python3-compat/recipes-scipy/lapack/lapack_3.9.0.bbappend \\
"

#remove legm2 as it causes compile error when populating sdk
DISTRO_FEATURES:remove:mx6leg = "lh-cellular-legacy"

# rootfs extra space in kbyte
# e.g. 8*1024=8192 KByte
# 16*1024= 16384 KByte
# 32*1024= 32768 KByte
# 64*1024= 65536 KByte
#IMAGE_ROOTFS_EXTRA_SPACE = "65536"

#IMAGE_INSTALL:remove = "leg-distroboot"

#
# additional development stuff not checked into repo
#
IMAGE_INSTALL:append = " nfs-utils-client"
# provide device user space utils
IMAGE_INSTALL:append = " usbutils pciutils lsscsi util-linux"
# provide gpio tools
IMAGE_INSTALL:append = " libgpiod libgpiod-dev libgpiod-tools"
# provide labgrid test requirements (imx6sleg-mcg)
# TODO(mweitner) should be build as build dependency no image install
IMAGE_INSTALL:append = " iperf3 can-utils"

# YP - Best Practises / Development
CORE_IMAGE_EXTRA_INSTALL:append = " strace"

# sota adaptations for testing purpose
#SOTA_ROLLBACK_WATCHDOG_TIME = "240"

# modem adaptations
# m2m apn
#LH_CELLULAR_APN="internet.m2mportal.de"
# telenor apn
# iot.liebherr.cxn -> private apn
#LH_CELLULAR_APN="iot.liebherr.cxn"
# connect.cxn -> public apn (preferred)
#LH_CELLULAR_APN="connect.cxn"

EOT
#quick solution enable/disable pip3 based python3 development on target
return 0
cat <<EOT2 >> "${project_root}/build/conf/local.conf"
# python on target improved development support
# - first install native gcc tooling and python3-distribution package
# - than python3-pip package installer support
IMAGE_INSTALL:append = " packagegroup-core-buildessential"
# python3-distribute is missing since python3 v3.3
#  - try to define python3-distribute as RDEPENDS on recipe level
#IMAGE_INSTALL:append = " python3-distribute"

IMAGE_INSTALL:append = " python3-setuptools python3-dev"
IMAGE_INSTALL:append = " cmake"
IMAGE_INSTALL:append = " python3-pip"

#fortran support
# enable fortran
FORTRAN_forcevariable = ",fortran"
#append FORTRAN_TOOLS
IMAGE_INSTALL:append = " \
  gfortran \
  gfortran-symlinks \
  libgfortran \
  libgfortran-dev \
"

#Use OPKG utilities to install ipk packages through package feeds
#FEED_DEPLOYDIR_BASE_DIR = "http://192.168.1.46:9999/"

#Fix for python 3.8 downgrade by using opkg package manager to install ipk packages
# - libnsl2 >= 1.3.0 is required for installing ...python3-unixadmin...ipk
#
#IMAGE_INSTALL:append = " libnsl2 libcrypto libxcrypt openssl libxcrypt-compat"
IMAGE_INSTALL:append = " libnsl2 libcrypto openssl"

IMAGE_EXTRA_FEATURES += "tools-sdk"
EOT2
