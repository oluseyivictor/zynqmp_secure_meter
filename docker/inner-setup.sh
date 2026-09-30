#!/bin/bash
# Runs INSIDE the container (invoked by ../docker-setup.sh via docker-run.sh).
# /export = this bundle (read-only), /home/petalinux/work = the build dir.
set -e

PROJ_NAME="${1:-secure_meter_project}"
WORK=/home/petalinux/work

if [ -d "$WORK/$PROJ_NAME" ]; then
	echo "ERROR: '$PROJ_NAME' already exists under the build directory. Remove it or pick another name."
	exit 1
fi

echo "=== Creating project '$PROJ_NAME' ==="
cd "$WORK"
petalinux-create -t project --template zynqMP -n "$PROJ_NAME"

PROJ_DIR="$WORK/$PROJ_NAME"

echo "=== Importing hardware description (extracts components/yocto - takes a while) ==="
cd "$PROJ_DIR"
petalinux-config --get-hw-description=/export/project-spec/hw-description --silentconfig

echo "=== Overlaying the real project-spec ==="
rm -rf "$PROJ_DIR/project-spec"
cp -a /export/project-spec "$PROJ_DIR/project-spec"

echo "=== Setting CONFIG_USER_LAYER paths (container-internal: /export and $PROJ_DIR) ==="
python3 - "$PROJ_DIR/project-spec/configs/config" "$PROJ_DIR" << 'PYEOF'
import re, sys
config_file, proj_dir = sys.argv[1], sys.argv[2]
with open(config_file) as f:
    content = f.read()
content = re.sub(
    r'CONFIG_USER_LAYER_0=".*"',
    'CONFIG_USER_LAYER_0="/export/layers/meta-arm/meta-arm-toolchain"',
    content, count=1)
content = re.sub(
    r'CONFIG_USER_LAYER_1=".*"',
    'CONFIG_USER_LAYER_1="/export/layers/meta-arm/meta-arm"',
    content, count=1)
content = re.sub(
    r'CONFIG_USER_LAYER_2=".*"',
    'CONFIG_USER_LAYER_2="%s/project-spec/meta-optee-zynqmp"' % proj_dir,
    content, count=1)
with open(config_file, "w") as f:
    f.write(content)
print("CONFIG_USER_LAYER paths rewritten")
PYEOF

echo
echo "=== Done: $PROJ_DIR (inside the container; on your host that is your build-dir/$PROJ_NAME) ==="
