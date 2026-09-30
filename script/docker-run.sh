#!/bin/bash
# Reusable wrapper: runs a command inside the axu3eg-petalinux:2020.1
# container, with this export bundle mounted read-only at /export and your
# chosen build directory mounted at /home/petalinux/work (matching the
# absolute paths baked into project-spec/configs/config by docker-setup.sh).
#
# Builds the Docker image automatically on first use if it doesn't exist yet
# (needs docker/installer/petalinux-v2020.1-final-installer.run to be present
# - see docker/installer/PUT_INSTALLER_HERE.txt).
#
# Usage: ./docker-run.sh <build-dir> <command...>
# Example: ./docker-run.sh ~/secure_proj_build petalinux-build

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$1"
shift
if [ -z "$BUILD_DIR" ] || [ "$#" -eq 0 ]; then
	echo "Usage: $0 <build-dir> <command...>"
	exit 1
fi
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"

IMAGE="axu3eg-petalinux:2020.1"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
	INSTALLER="$EXPORT_DIR/docker/installer/petalinux-v2020.1-final-installer.run"
	if [ ! -f "$INSTALLER" ]; then
		echo "ERROR: $INSTALLER not found."
		echo "See docker/installer/PUT_INSTALLER_HERE.txt for where to get it."
		exit 1
	fi
	echo "=== Building $IMAGE (first time only - installs PetaLinux 2020.1, takes a while) ==="
	docker build -t "$IMAGE" -f "$EXPORT_DIR/docker/Dockerfile" "$EXPORT_DIR/docker"
fi

# Quote the command so it survives the bash -c boundary intact.
CMD_STR=""
for arg in "$@"; do
	CMD_STR="$CMD_STR $(printf '%q' "$arg")"
done

docker run --rm \
	--cap-add=SYS_ADMIN --cap-add=SYS_PTRACE \
	-v "$EXPORT_DIR:/export:ro" \
	-v "$BUILD_DIR:/home/petalinux/work" \
	"$IMAGE" bash -c "source /opt/pkg/petalinux/settings.sh && cd /home/petalinux/work && $CMD_STR"
