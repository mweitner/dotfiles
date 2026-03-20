#!/bin/bash
echo hallo world
# Local directory to run the build from.
# BitBake will create all its files here.
export YOCTO_BUILD_DIR_LOCAL="/opt/yocto/project/linux-lpo/local-build"

# Define the build directory on the NAS. This is the source code location.
export YOCTO_SOURCE_DIR="/mnt/data/dev/linux-lpo/build"
echo $YOCTO_SOURCE_DIR

# Set the working directory to the local directory.
cd "$YOCTO_BUILD_DIR_LOCAL" || { echo "Error: Failed to change to local build directory."; exit 1; }
pwd

# Run BitBake from this local directory.
# The --buildfile option tells BitBake where to find the recipe files.
# The --read option tells BitBake to read the configuration from your NAS.
/mnt/data/dev/linux-lpo/layers/poky/bitbake/bin/bitbake \
    --read="$YOCTO_SOURCE_DIR/conf/local.conf" \
    --buildfile="$YOCTO_SOURCE_DIR/conf/bblayers.conf" \
    "$@"
# Pass all arguments ($@) to BitBake, allowing you to specify targets like 'core-image-minimal'.
