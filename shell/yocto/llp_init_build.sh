#!/bin/bash

#
# llp_init_build.sh - Init the llp yp build environment
#
# Works for LLP base repo, as well as project specific derivates like
# linux-dps, linux-leg4it, linux-smd, ...
#

function print_usage() {
  echo "Usage: source llp_init_build.sh <distro-layer> <flags>"
  echo " <distro-layer> (optional) := the name of the meta layer of the distro."
  printf "\tDefault: meta-liebherr-distro\n"
  printf "\tThe script evaluates automatically to the location of meta layer.\n"
  echo " <flags> (optional) := config feature enable flags"
  printf "\t-llpnetboot      := enable netboot feature (nfsclient)\n"
  printf "\t-llpdev          := enable development features\n"
  printf "\t-llpnodistroboot := disables distroboot user space service\n"
  printf "\t-llpnetwork      := enable network tooling like mt, ...\n"
  printf "\t-llpscfwdev      := enable NXP scu firmware development using meta-imx-scfw layer\n"
  printf "\t-llpbus          := enable bus tooling like lsusb, lspci, gpio-tools, ...\n"
  printf "\t-llppythontest   := enable python on-target test tools pip, ...\n"
  printf "\t-llpsotatest     := enable sota test where sota distro variables are changed\n"
  printf "\t-llpmixed        := enable mixed build support inside docker and outside\n"
  printf "\t-llpdocker       := activate docker build\n"
}

function filter_arguments() {
  # :return llp_filter_result: the filtered argument list
  #  it filters out -llp and meta- arguments, where -llp are the feature flags
  #  and meta- is the distro-layer name
  for var in "$@"; do
    shift
    [[ "$var" = -llp* ]] || [[ "$var" = meta-* ]] && continue
    set -- "$@" "$var"
  done
  llp_filter_result="$@"
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
  if [[ "$1" = -llp* ]]; then
    return 0 #< guard it is -llp argument -> no distro_layer arg given
  fi

  if [[ "$1" = meta-* ]]; then
    echo "found"
    return 1 #< distro-layer argument given
  fi
  return 0
}

function print_feature_summary() {
  cat "${project_root}/build/conf/feature_summary.txt"
}

function create_feature_summary() {
  local feature_file="${project_root}/build/conf/feature_summary.txt"
  rm -f "${feature_file}"
  if [ "${docker_build_support}" = "1" ]; then
    echo "[llp_init_build] docker_build_support=on (1)" >> "${feature_file}"
  else
    echo "[llp_init_build] docker_build_support=off (0)" >> "${feature_file}"
  fi
  if [ "${mixed_build_support}" = "1" ]; then
    echo "[llp_init_build] mixed_build_support=on (1)" >> "${feature_file}"
  else
    echo "[llp_init_build] mixed_build_support=off (0)" >> "${feature_file}"
  fi
  if [ "${devtool_workspace_active}" = "1" ]; then
    echo "[llp_init_build] devtool_workspace_active=on (1)" >> "${feature_file}"
  else
    echo "[llp_init_build] devtool_workspace_active=off (0)" >> "${feature_file}"
  fi
    
  if [ "${netboot_support}" = "1" ]; then
    echo "[llp_init_build] netboot_support=on (1)" >> "${feature_file}"
  else
    echo "[llp_init_build] netboot_support=off (0)" >> "${feature_file}"
  fi

  if [ "${dev_support}" = "1" ]; then
    echo "[llp_init_build] dev_support=on (1)" >> "${feature_file}"

    if [ "${network_support}" = "1" ]; then
      echo "[llp_init_build]\tnetwork_support=on (1)" >> "${feature_file}"
    else
      echo "[llp_init_build]\tnetwork_support=off (0)" >> "${feature_file}"
    fi
    
    if [ "${scfwdev_support}" = "1" ]; then
      echo "[llp_init_build]\tscfwdev_support=on (1)" >> "${feature_file}"
    else
      echo "[llp_init_build]\tscfwdev_support=off (0)" >> "${feature_file}"
    fi
 
    if [ "${nodistroboot_support}" = "1" ]; then
      echo "[llp_init_build]\tdistroboot_support=off (nodistroboot_support=1)" >> "${feature_file}"
    else
      echo "[llp_init_build]\tdistroboot_support=on (nodistroboot_support=0)" >> "${feature_file}"
    fi
  
    if [ "${bus_support}" = "1" ]; then
      echo "[llp_init_build]\tbus_support=on (1)" >> "${feature_file}"
    else
      echo "[llp_init_build]\tbus_support=off (0)" >> "${feature_file}"
    fi
  
    if [ "${pythontest_support}" = "1" ]; then
      echo "[llp_init_build]\tpythontest_support=on (1)" >> "${feature_file}"
    else
      echo "[llp_init_build]\tpythontest_support=off (0)" >> "${feature_file}"
    fi
  
    if [ "${sotatest_support}" = "1" ]; then
      echo "[llp_init_build]\tsotatest_support=on (1)" >> "${feature_file}"
    else
      echo "[llp_init_build]\tsotatest_support=off (0)" >> "${feature_file}"
    fi
  else
    echo "[llp_init_build] dev_support=off (0)" >> "${feature_file}"
    echo "[llp_init_build]\tnetwork_support=off (0)" >> "${feature_file}"
    echo "[llp_init_build]\tscfwdev_support=off (0)" >> "${feature_file}"
    echo "[llp_init_build]\tdistroboot_support=on (nodistroboot_support=0)" >> "${feature_file}"
    echo "[llp_init_build]\tbus_support=off (0)" >> "${feature_file}"
    echo "[llp_init_build]\tpythontest_support=off (0)" >> "${feature_file}"
    echo "[llp_init_build]\tsotatest_support=off (0)" >> "${feature_file}"
  fi
  print_feature_summary
}

if [ "${BASH_SOURCE}" = "${0}" ]; then
  echo "[llp_init_build] BASH_SOURCE: ${BASH_SOURCE}"
	printf "\\n[llp_init_build] Error: This script must to be sourced\\n\\n"
  return 254
fi

echo "args:$#, arg[0]=$0, arg[1]=$1, arg[*]=$@"
if [[ $# -gt 0 ]]; then
    if [[ "$1" = "-h" ]]; then
      print_usage
      return 0
    fi 
fi

yp_build_mixed_project_root="/opt/yocto/workspace"
yp_build_mixed_project_build_root="${yp_build_mixed_project_root}/build"
yp_build_mixed_project_name=""
yp_build_mixed_project_root_sources="${yp_build_mixed_project_root}/layers"

project_root=$(pwd)
project_name=$(basename "${project_root}")
project_build_root="${project_root}/build"
yp_build_mixed_project_name="${project_name}"

if [[ -h "${project_root}" ]]; then
  # as project root is a symlink, read the target file name
  # otherwise, the name would be workspace as the default symlink name for
  # mixed build environment which supports docker and native builds at the
  # same time.
  # Its important to have specific project name instead of a generic name like
  # workspace. See project_name usage at keys folder etc.
  project_name=$(basename $(readlink -f "${project_root}"))
fi

function is_build_mixed_project_supported() {
  # provides flag if mixed build is supported
  # @return 0 if mixed build is supported. Otherwise >0
  if [[ -d "${yp_build_mixed_project_root}" ]] && [[ -d "${yp_build_mixed_project_build_root}" ]] && [[ -d "${yp_build_mixed_project_root_sources}" ]];then
    # all mixed build root folders exist
    # check project name
    local_yp_build_mixed_project_name=$(basename $(readlink -f "${yp_build_mixed_project_build_root}"))
    if [[ "${project_name}" != "${local_yp_build_mixed_project_name}" ]];then
      echo "Mixed build not supported as project name is not same as current active project"
      return 1
    fi
    return 0
  fi

  return 2
}

contains_arg "-llpdev" $@
dev_support="$?"
contains_arg "-llpnetboot" $@
netboot_support="$?"
contains_arg "-llpnodistroboot" $@
nodistroboot_support="$?"
contains_arg "-llpnetwork" $@
network_support="$?"
contains_arg "-llpscfwdev" $@
scfwdev_support="$?"
contains_arg "-llpbus" $@
bus_support="$?"
contains_arg "-llppythontest" $@
pythontest_support="$?"
contains_arg "-llpsotatest" $@
sotatest_support="$?"
contains_arg "-llpsign" $@
sign_support="$?"
contains_arg "-llpmixed" $@
mixed_build_support="$?"
contains_arg "-llpdocker" $@
docker_build_support="$?"
if [[ "${docker_build_support}" = "1" ]];then
  mixed_build_support=1
fi

project_source_root="${project_root}/layers"
project_distro_layer="meta-liebherr-distro"
contains_arg_distro_layer "$1"
if [[ $? = 1 ]]; then
  project_distro_layer="$1"
fi

echo "[llp_init_build] project_distro_layer: ${project_source_root}"
project_distro_layer_path=$(find "${project_source_root}" -iname "${project_distro_layer}"| head -n 1)
if [[ "${mixed_build_support}" = "1" ]];then
  if [[ is_build_mixed_project_supported ]];then
    # mixed build supported
    # important to change path to /opt/yocto/workspace/...
    #echo "[llp_init_build] Info: mixed build support enabled"
    project_distro_layer_path=$(find "${yp_build_mixed_project_root_sources}" -iname "${project_distro_layer}"| head -n 1)
    project_source_root="${yp_build_mixed_project_root_sources}"
    project_build_root="${yp_build_mixed_project_build_root}"
  else
	  printf "\\n[llp_init_build] Error: -llpmixed build support is asked for but is not supported.\\n\\n"
    return 253
  fi
fi
echo "[llp_init_build] project_distro_layer_path: ${project_distro_layer_path}"
if [[ ! -d "${project_distro_layer_path}" ]]; then
  echo "[llp_init_build] project_distro_layer_path: ${project_distro_layer_path}"
	printf "\\n[llp_init_build] Error: project_distro_layer_path does not exist.\\n\\n"
  return 253
fi
project_keys_path="/opt/yocto/keys/llp"
project_sota_auth_token="aef7858413e41439980c4c8996d989e0"
project_mqtt_password=""
project_mqtt_endpoint=""
if [[ "${project_distro_layer}" == "meta-liebherr-lpo-display" ]]; then
  project_keys_path="/opt/yocto/keys/lpo"
  project_sota_auth_token="388295f55db0ea38c65dd3821d4fa61b"
elif [[ "${project_distro_layer}" == "meta-liebherr-dps" ]]; then
  project_keys_path="/opt/yocto/keys/dps"
  project_sota_auth_token="3c10d7a590e002b542d4d975e41ece3b"
  project_mqtt_password="ZgPfrd2PDMi5qY7vyx8vG16oWxpfoQeL"
fi
export LH_IOT_CLOUD_MQTT_PASSWORD="${project_mqtt_password}"
#cloud endpoint is set at local.conf
#export LH_IOT_CLOUD_ENDPOINT="${project_mqtt_endpoint}"

echo "[llp_init_build] project_keys_path: ${project_keys_path}"
project_keys_name=""
if [[ ! -d "${project_keys_path}" ]]; then
  if [[ "${sign_support}" = "1" ]];then
	  printf "\\n[llp_init_build] Error: project_keys_path does not exist.\\n\\n"
    return 253
  else
    echo "[llp_init_build] Warning: ignoring missing project_keys_path folder, as sign_support disabled"
  fi
else
  project_keys_name=$(basename "${project_keys_path}")
  if [[ "${sign_support}" != "1" ]];then
    echo "[llp_init_build] Warning: ignoring existing project_keys_path folder, as sign_support disabled"
  fi
fi

echo "[llp_init_build] Project keys name: ${project_keys_name}"
echo "[llp_init_build] Project root: ${project_root}"
echo "[llp_init_build] Project name: ${project_name}"
echo "[llp_init_build] Project distro root: ${project_distro_layer_path}"

# --- Start of TEMPLATECONF adjustment for different Yocto releases ---
# Try the new Scarthgap path first
local_templateconf_candidate="${project_distro_layer_path}/conf/templates/default"

if [[ -d "${local_templateconf_candidate}" ]]; then
  echo "[llp_init_build] Found new Scarthgap TEMPLATECONF path: ${local_templateconf_candidate}"
  export TEMPLATECONF="${local_templateconf_candidate}"
else
  # Fallback to the old default path if the new one doesn't exist
  echo "[llp_init_build] New Scarthgap TEMPLATECONF path not found. Falling back to old path."
  export TEMPLATECONF="${project_distro_layer_path}/conf"
fi
# --- End of TEMPLATECONF adjustment ---

# do not export WORKSPACE as got strange behaviour with bitbake testsss....permission errors...
#export WORKSPACE="${project_root}"

devtool_workspace_active=0
if [[ -d "${project_root}/build/conf" ]]; then
  if cat "${project_root}/build/conf/bblayers.conf" |grep -q "build/workspace"; then
    devtool_workspace_active=1
  fi
  echo "[llp_init_build] Yocto config exists, removing it ..."
  rm -rd "${project_root}/build/conf"
  mkdir "${project_root}/build/conf"
fi
echo "devtool_workspace_active=${devtool_workspace_active}"

create_feature_summary

filter_arguments $@
set -- "${llp_filter_result}"
echo "[llp_init_build] Filtered arguments: $@"

if [[ "${docker_build_support}" = "1" ]];then
  pushd "${yp_build_mixed_project_root}"
  # Ensure TEMPLATECONF is passed into the Docker container
  PROJECT="${project_name}" PROJECT_KEYS="${project_keys_name}" \
    docker compose -f layers/liebherr/ci/docker-compose.yml -f /opt/yocto/keys/dps/docker-compose.yml run --rm --build \
    -e TEMPLATECONF="${TEMPLATECONF}" \
    --user $(id -u):$(id -g) \
    liebherr-linux-build-container
  popd
  return 0
fi

echo "[llp_init_build] init oe:"
echo "[llp_init_build] ${project_source_root}/poky/oe-init-build-env ${project_build_root}"
# The oe-init-build-env script will now use the TEMPLATECONF we exported above
. "${project_source_root}/poky/oe-init-build-env" "${project_build_root}"

export SOTA_AUTH_TOKEN="${project_sota_auth_token}"
echo "[llp_init_build] export SOTA_AUTH_TOKEN=${SOTA_AUTH_TOKEN}"
export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS} SOTA_AUTH_TOKEN"
if [[ ! -z "${project_mqtt_password}" ]];then
  export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS} LH_IOT_CLOUD_MQTT_PASSWORD"
fi
if [[ "${sign_support}" = "1" ]];then
  export SWUPDATE_PASSWORD_FILE="${project_keys_path}/swupdate-password.txt"
  echo "[llp_init_build] export SWUPDATE_PASSWORD_FILE=${SWUPDATE_PASSWORD_FILE}"
  export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS} SWUPDATE_PASSWORD_FILE"
else
  echo "[llp_init_buid] Warning: signing support is not enabled, do not extend BB_ENV_PASSTHROUGH_ADDITIONS variable"
fi
# quick fix add lpo variable LPO_DATASTATION_PRIVATEKEY
if [[ -f "${project_keys_path}/id_rsa_lpo_datastation" ]]; then
  echo "[llp_init_build] found LPO_DATASTATION_PRIVATEKEY key file"
  export LPO_DATASTATION_PRIVATEKEY="${project_keys_path}/id_rsa_lpo_datastation"
  echo "[llp_init_build] export LPO_DATASTATION_PRIVATEKEY=${LPO_DATASTATION_PRIVATEKEY}"
  export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS} LPO_DATASTATION_PRIVATEKEY"
else
  echo "[llp_init_build] Warning: LPO_DATASTATION_PRIVATEKEY key file not found"
fi
# quick fix add lpo variable MOSQUITTO_PSK_FILE
if [[ -f "${project_keys_path}/mosquitto-psk.txt" ]]; then
  echo "[llp_init_build] found MOSQUITTO_PSK_FILE key file"
  export MOSQUITTO_PSK_FILE="${project_keys_path}/mosquitto-psk.txt"
  echo "[llp_init_build] export MOSQUITTO_PSK_FILE=${MOSQUITTO_PSK_FILE}"
  export BB_ENV_PASSTHROUGH_ADDITIONS="${BB_ENV_PASSTHROUGH_ADDITIONS} MOSQUITTO_PSK_FILE"
else
  echo "[llp_init_build] Warning: MOSQUITTO_PSK_FILE key file not found"
fi
echo "[llp_init_build] export BB_ENV_PASSTHROUGH_ADDITIONS=${BB_ENV_PASSTHROUGH_ADDITIONS}"

if [ "${netboot_support}" = "1" ]; then
cat <<EOT >> "${project_root}/build/conf/local.conf"
#SOTA_ROLLBACK_WATCHDOG_TIME:imx6q-display5="3min"
#LH_LPO_LEGACY_SW_DISPLAY5_SUPPORT="true"
#CORE_IMAGE_EXTRA_INSTALL:append = " util-linux-sfdisk"

#
# additional development stuff not checked into repo
# - empty-root-password support
# - netboot support (nfs-utils-client)
#

#EXTRA_IMAGE_FEATURES += " empty-root-password allow-root-login allow-empty-password"

INCOMPATIBLE_LICENSE_EXCEPTIONS:append:pn-lpo-display-image = " \
    binutils:GPL-3.0-only \
    gdb:GPL-3.0-only \
    gdb:LGPL-3.0-only \
    gdbserver:GPL-3.0-only \
    gdbserver:LGPL-3.0-only \
    libbfd:GPL-3.0-only \
    libopcodes:GPL-3.0-only \
    mpfr:GPL-3.0-or-later \
    mpfr:LGPL-3.0-or-later \
"
IMAGE_INSTALL:append = " nfs-utils-client"
IMAGE_INSTALL:append:imx6q-display5 = " ldd binutils strace gdb gdbserver less vim"

#TODO integrate rootfs post command into image recipe dynamically for
# development purposes

#inject_ssh_authorized_key() {
#    cat /home/ldcwem0/.ssh/id_ed25519_lpo_dev_root.pub >> ${IMAGE_ROOTFS}/home/root/.ssh/authorized_keys
#}

#ROOTFS_POSTPROCESS_COMMAND:prepend = "inject_ssh_authorized_key;"
EOT
fi

if [ "${devtool_workspace_active}" = "1" ]; then
#  Add workspace (devtool support)
cat <<EOT >> "${project_root}/build/conf/bblayers.conf"
BBLAYERS:append = " ${project_root}/build/workspace"
EOT
fi

if [ "${dev_support}" = "0" ]; then
  create_feature_summary
  return 0
fi

if [ "${network_support}" = "1" ]; then
cat <<EOT >> "${project_root}/build/conf/bblayers.conf"

#
# additional development stuff not checked into repo
# - meta-networking layer
#

BBLAYERS:append = " ${project_root}/layers/meta-openembedded/meta-networking/"
EOT
cat <<EOT >> "${project_root}/build/conf/local.conf"
# network dev/analysis meta-networking
# - traceroute mtr
# - mosquitto (development mqtt)
CORE_IMAGE_EXTRA_INSTALL:append = " traceroute mtr mosquitto"
CORE_IMAGE_EXTRA_INSTALL:append = " mosquitto libmosquitto1 libmosquittopp1 mosquitto-clients"
# network dev/analysis 
# - openembedded-core/iptables already included by meta-leg-cell (lh-legacy-mm)
# - openembedded-networking/tcpdump required to add here
CORE_IMAGE_EXTRA_INSTALL:append = " tcpdump"
# add iproute2 as it is not included in busybox anymore which breaks ip command
# where ip link set can0 type can ... does not work!
CORE_IMAGE_EXTRA_INSTALL:append = " iproute2"
EOT
fi

if [ "${scfwdev_support}" = "1" ]; then
cat <<EOT >> "${project_root}/build/conf/bblayers.conf"

#
# The scfw meta layer used for scu firmware development
#

BBLAYERS:append = " ${project_root}/layers/meta-imx-scfw"
EOT
fi

if [ "${nodistroboot_support}" = "1" ]; then
cat <<EOT >> "${project_root}/build/conf/local.conf"

#
# additional project specific stuff no checked into repo
# distroboot support disabled
#

IMAGE_INSTALL:remove = "leg-distroboot"
EOT
fi

if [ "${bus_support}" = "1" ]; then
cat <<EOT >> "${project_root}/build/conf/local.conf"

#
# additional project specific stuff no checked into repo
# io bus utilities, can utils, strace, python-pip
#

# provide device user space utils
IMAGE_INSTALL:append = " usbutils pciutils lsscsi util-linux"
# provide gpio tools
IMAGE_INSTALL:append = " libgpiod libgpiod-dev libgpiod-tools"
# provide labgrid test requirements (imx6sleg-mcg)
# TODO(mweitner) should be build as build dependency no image install
IMAGE_INSTALL:append = " iperf3 can-utils"

# YP - Best Practises / Development
CORE_IMAGE_EXTRA_INSTALL:append = " strace"
EOT
fi

if [ "${pythontest_support}" = "1" ]; then
cat <<EOT >> "${project_root}/build/conf/local.conf"

#
# additional project specific stuff no checked into repo
# python3 test support
#

# python on target improved development support
IMAGE_INSTALL:append = " python3-pip"
EOT
fi

if [ "${sotatest_support}" = "1" ]; then
cat <<EOT >> "${project_root}/build/conf/local.conf"

#
# additional project specific stuff no checked into repo
# sota test support
#

# sota adaptations for testing purpose
SOTA_ROLLBACK_WATCHDOG_TIME = "240"
EOT
fi
create_feature_summary
