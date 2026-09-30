#!/bin/bash
# Runs INSIDE the container. Assembles BOOT.BIN with the OP-TEE partition.
# Requires petalinux-build (full) and petalinux-build -c optee-os to have
# already completed successfully for this project.
set -e

PROJ_NAME="${1:-secure_meter_project}"
PROJ_DIR="/home/petalinux/work/$PROJ_NAME"

if [ ! -d "$PROJ_DIR" ]; then
	echo "ERROR: $PROJ_DIR not found."
	exit 1
fi

export PATH="/opt/pkg/petalinux/components/yocto/buildtools/sysroots/x86_64-petalinux-linux/usr/bin:$PATH"
export LD_LIBRARY_PATH="/opt/pkg/petalinux/components/yocto/buildtools/sysroots/x86_64-petalinux-linux/usr/lib:$LD_LIBRARY_PATH"

TEE_RAW="$(find "$PROJ_DIR/build/tmp/deploy/images" -name tee_raw.bin | head -1)"
if [ -z "$TEE_RAW" ]; then
	echo "ERROR: tee_raw.bin not found - run 'petalinux-build -c optee-os' first."
	exit 1
fi

BIF="$PROJ_DIR/optee_boot.bif"
cat > "$BIF" << EOF
the_ROM_image:
{
	[bootloader, destination_cpu=a53-0] $PROJ_DIR/images/linux/zynqmp_fsbl.elf
	[pmufw_image] $PROJ_DIR/images/linux/pmufw.elf
	[destination_device=pl] $PROJ_DIR/project-spec/hw-description/design_1_wrapper.bit
	[destination_cpu=a53-0, exception_level=el-3, trustzone] $PROJ_DIR/images/linux/bl31.elf
	[destination_cpu=a53-0, exception_level=el-1, trustzone, load=0x60000000, startup=0x60000000] $TEE_RAW
	[destination_cpu=a53-0, load=0x00100000] $PROJ_DIR/images/linux/system.dtb
	[destination_cpu=a53-0, exception_level=el-2] $PROJ_DIR/images/linux/u-boot.elf
}
EOF

bootgen -image "$BIF" -arch zynqmp -o "$PROJ_DIR/images/linux/BOOT_OPTEE.BIN" -w on

echo
echo "Done: $PROJ_DIR/images/linux/BOOT_OPTEE.BIN"
echo "(on your host: <build-dir>/$PROJ_NAME/images/linux/BOOT_OPTEE.BIN)"
echo "Flash this alongside images/linux/image.ub and images/linux/boot.scr"
echo "(rename to BOOT.BIN/image.ub/boot.scr on the SD card)."
