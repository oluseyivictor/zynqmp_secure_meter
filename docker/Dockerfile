# PetaLinux 2020.1 build environment for the AXU3EG secure_proj OP-TEE
# project.
#
# PetaLinux only supports specific Linux hosts (Ubuntu 16.04.x/18.04.x, CentOS/RHEL
# 7.4-7.7 for the 2020.1 release) and refuses to run as root, so this image builds
# a non-root user on Ubuntu 18.04 and installs PetaLinux into it. Building and
# running this container works the same regardless of your actual host OS/version
# (that's the whole point) - this is what was used to develop and verify this
# project in the first place.
#
# Build context expectations:
#   docker/installer/petalinux-v2020.1-final-installer.run  <- you provide this
#     (download from the AMD/Xilinx downloads portal; requires an AMD account
#     login, so this can't be fetched automatically - search "PetaLinux 2020.1")
#
# Build the image (from the secure_proj_export/ directory):
#   docker build -t axu3eg-petalinux:2020.1 -f docker/Dockerfile docker
#
# See script/docker-setup.sh / script/docker-build-boot-bin.sh in this bundle for the actual
# project setup/build flow - you shouldn't need to invoke `docker run` by hand.

FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# --- Host package prerequisites -------------------------------------------------
# Based on AMD's documented PetaLinux/Yocto build-host package list for Ubuntu
# 18.04 (UG1144). This list has historically drifted slightly release to release —
# if the PetaLinux installer or `petalinux-build` complains about a missing tool,
# add the package here and rebuild (Docker layer caching keeps this fast).
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
    iproute2 gawk python3 build-essential gcc git make net-tools \
    libncurses5-dev openbsd-inetd tftpd zlib1g-dev libssl-dev flex bison libselinux1 \
    gnupg wget diffstat chrpath socat xterm autoconf libtool tar unzip \
    texinfo gcc-multilib automake screen pax gzip cpio python3-pip \
    python3-pexpect xz-utils debianutils iputils-ping python3-git \
    python3-jinja2 libegl1-mesa libsdl1.2-dev pylint bc libtinfo5 \
    subversion lib32z1 lib32stdc++6 locales sudo file zlib1g:i386 rsync x11-utils xvfb dbus-x11 lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Yocto/bitbake require a real UTF-8 locale.
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# PetaLinux/Yocto builds require /bin/sh to be bash, not dash (Ubuntu's default).
RUN echo "dash dash/sh boolean false" | debconf-set-selections \
    && dpkg-reconfigure dash

# --- Non-root build user ---------------------------------------------------------
RUN useradd -m -s /bin/bash petalinux \
    && echo "petalinux ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# --- Install PetaLinux 2020.1 -----------------------------------------------------
COPY installer/petalinux-v2020.1-final-installer.run /tmp/petalinux-installer.run
RUN mkdir -p /opt/pkg/petalinux && chown petalinux:petalinux /opt/pkg/petalinux
RUN chmod +x /tmp/petalinux-installer.run

USER petalinux
WORKDIR /home/petalinux

# NOTE: the installer prompts to accept several EULAs interactively. `yes` answers
# every prompt with "y", which works for straightforward accept-license flows but
# has not been verified against the actual 2020.1 installer's exact prompt sequence
# in this environment — if this step fails or hangs, run it manually first to see
# the real prompts, then adjust this RUN line accordingly.
RUN yes | /tmp/petalinux-installer.run -d /opt/pkg/petalinux

RUN echo "source /opt/pkg/petalinux/settings.sh" >> /home/petalinux/.bashrc

CMD ["/bin/bash"]
