# Compile the OP-TEE SMC dispatcher (services/spd/opteed/*.c) directly into
# bl31.elf, and set BL31's compiled-in default BL32_BASE/BL32_LIMIT to match
# OP-TEE's own hardcoded TZDRAM_BASE/TZDRAM_SIZE (optee_os/core/arch/arm/
# plat-zynqmp/platform_config.h: TZDRAM_BASE=0x60000000, TZDRAM_SIZE=0x10000000 /
# 256MiB) - these must always agree, see optee-tz/docs/memory-map.md.
#
# NOTE: must use the _zynqmp-suffixed variable, not the plain EXTRA_OEMAKE.
# arm-trusted-firmware.inc's own EXTRA_OEMAKE_zynqmp_append operations mean
# bitbake resolves the final EXTRA_OEMAKE value entirely from the _zynqmp
# override chain once it's active for this MACHINE - appends to the plain,
# unsuffixed EXTRA_OEMAKE are silently dropped from the final value (verified
# by inspecting `bitbake -e arm-trusted-firmware`'s variable history).
#
# Note: BL32=<path-to-tee.bin> is deliberately NOT set here - it would be inert.
# Xilinx's zynqmp recipe only ever builds the `bl31` make target (never `fip`),
# and BL32=<path> only feeds TF-A's fiptool packaging path. The real OP-TEE
# binary is packaged into BOOT.BIN as its own BIF partition (see boot/optee_boot.bif)
# and loaded by FSBL directly; BL31 jumps to it via the FSBL ATFHandoffParams
# handoff (or, absent that, the BL32_BASE default set here).
EXTRA_OEMAKE_zynqmp += "SPD=opteed ZYNQMP_BL32_MEM_BASE=0x60000000 ZYNQMP_BL32_MEM_SIZE=0x10000000"
