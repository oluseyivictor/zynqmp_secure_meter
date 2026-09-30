COMPATIBLE_MACHINE = "zynqmp-generic"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"

# Override the stock 3.8.0 pin (023e33656e2c9557ce50ad63a98b2e2c9b51c118)
# with the exact commit verified working end-to-end on real AXU3EG hardware
# (4.10.0-370-g5858c37a6, confirmed via an official OP-TEE/build repo-based
# reference test before being adopted here - see optee_tz_project.md memory
# for the full story of how/why this specific commit was chosen over the
# stock pin, which hangs on this hardware).
SRCREV = "5858c37a66cbffccf7b047d0f9a52dee0ebbf06c"

# meta-arm's own optee-os_git.bb already vendors and applies a patch with
# exactly this purpose (0001-allow-setting-sysroot-for-libgcc-lookup.patch,
# in layers/meta-arm/meta-arm/recipes-security/optee/optee-os/) - but as
# shipped it was written against a newer upstream optee_os commit than the
# one pinned above (its pristine context includes $(comp-cflags$(sm)),
# which doesn't exist yet in mk/gcc.mk at our commit), so it failed to apply
# here ("can't find file to patch") and aborted do_patch before anything
# else got a chance to run. `SRC_URI_remove` in a bbappend did not
# reliably drop it in testing (root cause not fully pinned down), so instead
# its content was directly replaced (same filename, same SRC_URI entry
# already wired up by the base recipe) with a corrected version generated
# straight from a `diff -u` against the actual pristine file at this exact
# SRCREV - no separate patch file/SRC_URI entry needed here.

# meta-arm's optee-os.bb defaults both OPTEEMACHINE and OPTEEOUTPUTMACHINE to
# ${MACHINE} ("zynqmp-generic"), but optee_os's own platform id for this SoC
# family is "zynqmp" (matches its core/arch/arm/plat-zynqmp/ directory).
# OPTEEMACHINE feeds PLATFORM= for the actual build invocation; OPTEEOUTPUTMACHINE
# is used separately by do_install to locate the built output under
# out/arm-plat-<OPTEEOUTPUTMACHINE>/ - both must be overridden together or
# do_install fails to find what do_compile actually produced.
OPTEEMACHINE = "zynqmp"
OPTEEOUTPUTMACHINE = "zynqmp"

# Core (not just TA) logging - the stock recipe only sets CFG_TEE_TA_LOG_LEVEL=0,
# leaving OP-TEE's own boot banner/diagnostics invisible. Needed while bringing
# up the BL31->OP-TEE handoff for the first time; this recipe has no machine-
# suffix complexity (unlike arm-trusted-firmware's EXTRA_OEMAKE_zynqmp), so a
# plain append is sufficient here.
EXTRA_OEMAKE += "CFG_TEE_CORE_LOG_LEVEL=3"

# The updated optee_os revision (SRCREV override above, pinned to the exact
# commit proven working against an official reference build,
# 4.10.0-370-g5858c37a6) needs python3-cryptography at build time
# (scripts/pem_to_pub_c.py, for TA signing-key embedding) - not a dependency
# the older 3.8.0 pin needed. meta-python already ships a working recipe
# (python-cryptography_2.7.bb, BBCLASSEXTEND native), just wasn't pulled in
# before now.
DEPENDS += "python3-cryptography-native"

# mk/gcc.mk computes the *real* linker input as libgcc$(sm) (arch/mode
# suffixed, e.g. libgcc_ta_arm64), via
# `$(shell $(CC$(sm)) $(CFLAGS$(arch-bits-$(sm))) -print-libgcc-file-name)`.
# The bare, unsuffixed `libgcc` name is deliberately poisoned by gcc.mk itself
# (`libgcc := --bad-libgcc-variable`, "Define these to something to discover
# accidental use") specifically to catch code that forgets the $(sm) suffix -
# so overriding plain `libgcc=` via EXTRA_OEMAKE (tried earlier) was
# overriding a variable nothing actually links with; the real ld.bfd
# invocations still showed a bare unqualified "libgcc.a" positional arg
# because $(CC$(sm)) -print-libgcc-file-name, invoked with no --sysroot, can't
# resolve its own runtime lib against this Yocto-managed sysroot layout.
#
# DEPENDS on libgcc correctly stages the real libgcc.a into
# ${RECIPE_SYSROOT}/usr/lib/aarch64-xilinx-linux/9.2.0/libgcc.a (confirmed via
# find), and bitbake already exports LIBGCC_LOCATE_CFLAGS=--sysroot=${RECIPE_SYSROOT}
# into the build environment for exactly this purpose - but stock mk/gcc.mk
# never consumes that variable when shelling out to -print-libgcc-file-name.
# Fixed via the corrected 0001-allow-setting-sysroot-for-libgcc-lookup.patch
# in layers/meta-arm/meta-arm/recipes-security/optee/optee-os/ (see the
# comment above) - adds $(LIBGCC_LOCATE_CFLAGS) to that shell invocation so
# it actually finds the staged libgcc.a via --sysroot, the same way OE's own
# gcc-runtime consumers do.
DEPENDS += "libgcc"

# plat-zynqmp's link.mk (unlike e.g. plat-rcar) never generates tee_raw.bin -
# only the header+pager+pageable set (tee-header_v2.bin/tee-pager_v2.bin/
# tee-pageable_v2.bin) plus the combined tee.bin (which has OP-TEE's own image
# header as its first bytes, NOT executable code at offset 0). A bootgen BIF
# that jumps directly to a raw-loaded binary's first byte (our case, since
# bootgen doesn't understand OP-TEE's header format) needs the *headerless*
# tee_raw.bin instead, confirmed against the official reference BIF at
# https://github.com/OP-TEE/build/blob/master/zynqmp/bootImage-zynqmp-zcu102.bif
# which loads .../optee_os/out/arm/core/tee_raw.bin, not tee.bin. Generate it
# ourselves the same way plat-rcar's link.mk does (scripts/gen_tee_bin.py
# --out_tee_raw_bin), since plat-zynqmp doesn't do this itself. (Idempotent if
# a newer plat-zynqmp/link.mk ever starts doing this on its own too.)
do_compile_append() {
	${S}/scripts/gen_tee_bin.py --input ${B}/out/arm-plat-${OPTEEOUTPUTMACHINE}/core/tee.elf --out_tee_raw_bin ${B}/out/arm-plat-${OPTEEOUTPUTMACHINE}/core/tee_raw.bin
}

do_install_append() {
	install -m 644 ${B}/out/arm-plat-${OPTEEOUTPUTMACHINE}/core/tee_raw.bin ${D}${nonarch_base_libdir}/firmware/
}
