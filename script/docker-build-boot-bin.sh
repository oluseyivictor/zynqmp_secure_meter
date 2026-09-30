#!/bin/bash
# Assembles BOOT.BIN with the OP-TEE partition, inside the container.
# Usage: ./docker-build-boot-bin.sh <build-dir> [project-name]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$1"
PROJ_NAME="${2:-secure_meter_project}"

if [ -z "$BUILD_DIR" ]; then
	echo "Usage: $0 <build-dir> [project-name]"
	exit 1
fi

"$SCRIPT_DIR/docker-run.sh" "$BUILD_DIR" bash /export/docker/inner-build-boot-bin.sh "$PROJ_NAME"
