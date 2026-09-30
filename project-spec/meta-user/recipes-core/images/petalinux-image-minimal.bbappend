# OP-TEE Linux-side client tooling and demo CA/TA pairs (hello_world, random,
# aes, secure_storage) for functional testing of the BL31->OP-TEE handoff -
# forced in directly rather than via rootfs_config Kconfig toggles, which are
# gated behind COMPATIBLE_MACHINE visibility quirks already worked around via
# the bbappends in meta-optee-zynqmp/recipes-security/.
IMAGE_INSTALL_append = " optee-client optee-examples"
