# AXU3EG secure meter project

PetaLinux 2020.1 project for the ALINX AXU3EG board (Zynq UltraScale+
XCZU3EG), with TF-A and OP-TEE integrated into the boot chain:

```text
FSBL -> TF-A/BL31 -> OP-TEE/BL32 -> U-Boot/BL33 -> Linux
```

The project includes the `meterd` Linux client and an OP-TEE Trusted Application.
The Trusted Application keeps its ECDSA P-256 key and monotonic counter in the
secure world and signs meter readings requested by `meterd`.

## Requirements

- A Linux host with Docker installed and usable by the current user.
- The AMD/Xilinx PetaLinux 2020.1 installer:
  `petalinux-v2020.1-final-installer.run`.
- Internet access. The first build downloads the PetaLinux/Yocto sources.
- Two writable storage locations, which may be on the same filesystem:
  - At least 40 GB free in Docker's storage filesystem for the build image.
  - At least 50 GB free for the PetaLinux build directory.

Check the relevant free space before starting:

```bash
docker info --format '{{.DockerRootDir}}'
df -h /var/lib/docker /path/to/build-directory
```

If Docker reports a different root directory, check that path instead of
`/var/lib/docker`.

PetaLinux 2020.1 supports older host distributions. The supplied Dockerfile
uses Ubuntu 18.04 so that no native PetaLinux installation is required.

## Prepare the source tree

From the root of the downloaded project, place the installer at this exact
path:

```text
docker/installer/petalinux-v2020.1-final-installer.run
```

Make it executable and confirm that Docker is available:

```bash
chmod +x docker/installer/petalinux-v2020.1-final-installer.run
docker version
```

The installer is licensed software and is therefore not included in this
repository. Download the 2020.1 release from the AMD/Xilinx download portal.

## Build

Choose a writable build directory outside the downloaded source tree. Keeping
the generated project separate makes the source export reusable and prevents
large build files from being mixed with it.

The examples below use `/path/to/secure-meter-build`; replace it with an absolute
path on a filesystem with sufficient free space.

```bash
mkdir -p /path/to/secure-meter-build

# The container's non-root build user has UID 1000. On hosts where your user
# has a different UID, grant it access to this dedicated build directory.
if [ "$(id -u)" -ne 1000 ]; then
  sudo setfacl -m u:1000:rwx /path/to/secure-meter-build
fi

# Create the Docker image on first use, create the PetaLinux project, import
# the hardware description, and apply this repository's project configuration.
./script/docker-setup.sh /path/to/secure-meter-build

# Build Linux, the root filesystem, FSBL, PMU firmware, TF-A, U-Boot, OP-TEE,
# the OP-TEE examples, and the remaining image dependencies.
./script/docker-run.sh /path/to/secure-meter-build \
  bash -c "cd secure_meter_project && petalinux-build"

# Assemble the final boot image containing OP-TEE.
./script/docker-build-boot-bin.sh /path/to/secure-meter-build
```

The first `docker-setup.sh` run builds the `axu3eg-petalinux:2020.1` image and
can take several minutes. The first PetaLinux build downloads upstream sources
and takes considerably longer.

The build directory must be writable by the non-root `petalinux` user inside
the container. That user has UID 1000. If `setfacl` is unavailable, use the
host's normal ownership or ACL tools to grant UID 1000 access to this dedicated
directory. Do not make an unrelated parent directory world-writable.

Warnings that the container OS is unsupported and that `/tftpboot` is
unavailable are expected. They do not indicate a failed build. Success is
reported as:

```text
[INFO] successfully built project
```

### Optional commands

Rebuild OP-TEE alone after changing its recipe or source configuration:

```bash
./script/docker-run.sh /path/to/secure-meter-build \
  bash -c "cd secure_meter_project && petalinux-build -c optee-os"
```

Create a conventional boot image without the OP-TEE partition:

```bash
./script/docker-run.sh /path/to/secure-meter-build \
  bash -c "cd secure_meter_project && petalinux-package --boot --u-boot --fsbl --fpga --force"
```

This optional command produces `BOOT.BIN`. It is not the image to use when
testing the secure OP-TEE boot chain.

## Build outputs

The files required for the SD card are generated under:

```text
/path/to/secure-meter-build/secure_meter_project/images/linux/
```

Copy these files to the FAT boot partition:

| Generated file | SD-card filename |
| --- | --- |
| `BOOT_OPTEE.BIN` | `BOOT.BIN` |
| `image.ub` | `image.ub` |
| `boot.scr` | `boot.scr` |

`BOOT_OPTEE.BIN` contains the FSBL, PMU firmware, FPGA bitstream, TF-A,
OP-TEE, device tree, and U-Boot. `image.ub` contains the Linux image and root
filesystem.

## Boot and verify

Connect to the board's PS UART at 115200 baud, 8 data bits, no parity, and one
stop bit. The default login is:

```text
username: root
password: root
```

After Linux boots, verify that the OP-TEE driver is active:

```sh
dmesg | grep -i optee
ls -l /dev/tee*
```

The device list should include `/dev/tee0` and `/dev/teepriv0`.

The root filesystem uses SysV init, while the supplied OP-TEE client recipe
only provides a systemd service. Start the supplicant manually before running
examples that require it:

```sh
tee-supplicant -d &
```

Run the included examples:

```sh
optee_example_hello_world
optee_example_random
optee_example_secure_storage
```

Run the secure meter application after starting `tee-supplicant`:

```sh
meterd
```

Its output includes the reading, a monotonically increasing counter, and the
signature produced by the Trusted Application.

Expected checks:

- `hello_world` increments the test value from 42 to 43.
- `random` returns different values over repeated runs.
- `secure_storage` alternates between creating and deleting its persistent
  test object on successive runs.

## Repository layout

- `project-spec/` contains the PetaLinux configuration, hardware description,
  device-tree additions, kernel configuration, root-filesystem selection, and
  the OP-TEE integration layer. The meter recipe is under
  `project-spec/meta-user/recipes-apps/meter-secure-app/`.
- `layers/meta-arm/` supplies the OP-TEE recipes and the patch required by the
  pinned OP-TEE revision.
- `docker/` contains the Ubuntu 18.04/PetaLinux build image and the scripts run
  inside it.
- `script/` contains the host-side setup, build, and boot-image wrappers.

Generated sources, downloads, shared state, and build output are intentionally
excluded. They are recreated in the external build directory.

## Implementation notes

The checked-in configuration already includes the board-specific fixes needed
for a working secure boot:

- TF-A is built with the `opteed` secure-payload dispatcher and the matching
  trusted-memory layout.
- OP-TEE is pinned to the tested revision and builds a headerless `tee_raw.bin`
  for the Bootgen partition.
- The boot image assigns both the load and startup address for the raw OP-TEE
  payload.
- The kernel and device tree enable the OP-TEE driver and the AXU3EG Ethernet
  configuration required for reliable boot and login.
- The root filesystem uses `util-linux` `agetty` for reliable serial login.
- Only the tested `hello_world`, `random`, and `secure_storage` OP-TEE examples
  are included.

These settings are applied automatically by the supplied setup and build
scripts; no manual recipe, kernel, or device-tree edits are required.
