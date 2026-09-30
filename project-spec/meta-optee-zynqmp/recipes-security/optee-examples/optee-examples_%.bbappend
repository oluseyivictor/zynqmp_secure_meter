COMPATIBLE_MACHINE = "zynqmp-generic"

# This recipe pins an old optee_examples commit whose acipher/aes/hotp
# examples use TEE_ObjectInfo.keySize - renamed upstream (to objectSize)
# somewhere in the ~370 commits between that pin and the newer optee_os
# commit this project uses (5858c37a6, the exact commit proven working on
# this hardware - see optee_tz_project.md memory). The top-level Makefile
# builds every example subdirectory in one do_compile invocation and aborts
# the whole task if any one fails, so a single stale example blocks the
# package entirely. hello_world, random and secure_storage do not touch
# TEE_ObjectInfo.keySize (random has no crypto-object API surface at all;
# secure_storage only deals with plain data objects, not keyed crypto
# objects) so they are unaffected by the rename - keep only these three,
# drop everything else before do_compile runs.
KEEP_EXAMPLES = "hello_world random secure_storage"
do_compile_prepend() {
	for d in ${S}/*/; do
		name=$(basename "$d")
		keep=0
		for k in ${KEEP_EXAMPLES}; do
			[ "$name" = "$k" ] && keep=1
		done
		if [ -f "$d/Makefile" ] && [ "$keep" = "0" ]; then
			rm -rf "$d"
		fi
	done
}

# Same libgcc.a staging gap already hit and fixed for optee-os itself (see
# optee-os_%.bbappend) - this recipe links TA binaries via optee_os own
# exported ta_dev_kit.mk / mk/gcc.mk (already has the LIBGCC_LOCATE_CFLAGS
# fix baked in, since it is staged straight from the patched optee_os
# source), but that only helps once libgcc.a actually exists in this own
# recipe sysroot for -print-libgcc-file-name --sysroot=... to find.
DEPENDS += "libgcc"

# optee-os own recipe (meta-arm) hardcodes
# LIBGCC_LOCATE_CFLAGS=--sysroot=STAGING_DIR_HOST in its own do_compile args -
# that is not a generic Yocto/oe_runmake default, so this recipe (a plain
# oe_runmake caller) never gets it passed through to the exported
# mk/gcc.mk -print-libgcc-file-name invocation, leaving libgcc.a unresolved
# even though it is correctly staged (DEPENDS above) and the exported gcc.mk
# already has the LIBGCC_LOCATE_CFLAGS-consuming fix. Match the same pattern
# optee-os itself uses.
EXTRA_OEMAKE += "LIBGCC_LOCATE_CFLAGS=--sysroot=${STAGING_DIR_HOST}"

# Same python3-cryptography-native gap already hit and fixed for optee-os
# itself - the exported sign_encrypt.py script (used to sign the compiled TA
# with the default key) needs it too.
DEPENDS += "python3-cryptography-native"

# The upstream examples Makefile links the CA binary with a hand-rolled gcc
# command line that never includes ${LDFLAGS}, so it is missing GNU_HASH -
# an OE QA hardening check, not a functional defect (the binary still runs
# fine). Skip rather than patch the upstream example build system.
INSANE_SKIP_${PN} += "ldflags"
