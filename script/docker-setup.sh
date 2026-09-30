#!/bin/bash
# One-time setup: creates the secure_meter_project PetaLinux project inside
# a Docker build directory, using the axu3eg-petalinux:2020.1 container
# (built automatically on first run - see docker/installer/PUT_INSTALLER_HERE.txt).
#
# Usage: ./docker-setup.sh <build-dir> [project-name]
# Example: ./docker-setup.sh ~/secure_meter_build
#
# <build-dir> is a plain host directory (created if it doesn't exist) that
# will hold the actual PetaLinux project and all build output. Keep it
# outside this export bundle.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$1"
PROJ_NAME="${2:-secure_meter_project}"

if [ -z "$BUILD_DIR" ]; then
	echo "Usage: $0 <build-dir> [project-name]"
	exit 1
fi

"$SCRIPT_DIR/docker-run.sh" "$BUILD_DIR" bash /export/docker/inner-setup.sh "$PROJ_NAME"

echo
echo "Next steps (all via docker-run.sh, from this directory):"
echo "  ./docker-run.sh $BUILD_DIR bash -c \"cd $PROJ_NAME && petalinux-build\""
echo "  ./docker-run.sh $BUILD_DIR bash -c \"cd $PROJ_NAME && petalinux-build -c optee-os\""
echo "  ./docker-run.sh $BUILD_DIR bash -c \"cd $PROJ_NAME && petalinux-package --boot --u-boot --fsbl --fpga --force\""
echo "  ./docker-build-boot-bin.sh $BUILD_DIR $PROJ_NAME"
