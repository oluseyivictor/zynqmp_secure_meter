#
# Meter TA + meterd host app - companion code for
# "Edge Security by Design, Part 2: The Same Smart Meter on a Xilinx
# Zynq UltraScale+ MPSoC" (see project README.md for build/boot context).
#
SUMMARY = "Signed smart-meter reading demo: OP-TEE TA + Linux host (meterd)"
DESCRIPTION = "meterd (Linux) asks the meter Trusted Application (OP-TEE) \
to sign a reading. The TA holds an ECDSA P-256 key it can use but never \
export, plus a monotonic counter, both invisible to Linux."
HOMEPAGE = "https://github.com/oluseyivictor/zynqmp_secure_meter"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://Makefile \
           file://ta/Makefile \
           file://ta/sub.mk \
           file://ta/user_ta_header_defines.h \
           file://ta/meter_ta.c \
           file://ta/include/meter_ta.h \
           file://host/Makefile \
           file://host/meterd.c \
          "
S = "${WORKDIR}"

COMPATIBLE_MACHINE = "zynqmp-generic"

# Same DEPENDS optee-examples needs for this pinned optee_os SRCREV (see
# README "Known issues already fixed"): the TA is signed at build time by
# optee_os's exported sign_encrypt.py (needs python3-cryptography-native),
# and both the TA and CA link against libgcc.a via optee_os's own
# mk/gcc.mk, which needs the sysroot forwarded explicitly.
DEPENDS = "optee-client optee-os python3-cryptography-native libgcc"
inherit python3native

OPTEE_CLIENT_EXPORT = "${STAGING_DIR_HOST}${prefix}"
TEEC_EXPORT = "${STAGING_DIR_HOST}${prefix}"
TA_DEV_KIT_DIR = "${STAGING_INCDIR}/optee/export-user_ta"

EXTRA_OEMAKE = " TA_DEV_KIT_DIR=${TA_DEV_KIT_DIR} \
                 OPTEE_CLIENT_EXPORT=${OPTEE_CLIENT_EXPORT} \
                 TEEC_EXPORT=${TEEC_EXPORT} \
                 HOST_CROSS_COMPILE=${TARGET_PREFIX} \
                 TA_CROSS_COMPILE=${TARGET_PREFIX} \
                 LIBGCC_LOCATE_CFLAGS=--sysroot=${STAGING_DIR_HOST} \
                 V=1 \
               "

do_compile() {
    oe_runmake
}

do_install() {
    install -d ${D}${bindir}
    install -D -p -m0755 ${S}/host/meterd ${D}${bindir}

    install -d ${D}${nonarch_base_libdir}/optee_armtz
    install -D -p -m0444 ${S}/ta/*.ta ${D}${nonarch_base_libdir}/optee_armtz
}

FILES_${PN} += "${nonarch_base_libdir}/optee_armtz/"

# Same QA gap as optee-examples on this pinned toolchain: the host link
# line doesn't route $LDFLAGS through, so GNU_HASH is missing - cosmetic,
# not functional (see README).
INSANE_SKIP_${PN} += "ldflags"

PACKAGE_ARCH = "${MACHINE_ARCH}"
