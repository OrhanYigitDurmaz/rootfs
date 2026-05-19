#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: $0 <VERSION>}"
OUTPUT_DIR="$(pwd)/output"
ROOTFS=$(mktemp -d)
trap "rm -rf ${ROOTFS}" EXIT

mkdir -p "${OUTPUT_DIR}"

echo ">>> Bootstrapping Debian 13 (Trixie) minimal rootfs"
debootstrap --variant=minbase trixie "${ROOTFS}" http://deb.debian.org/debian

echo ">>> Installing OpenSSH server"
chroot "${ROOTFS}" apt-get install -y --no-install-recommends openssh-server

echo ">>> Configuring SSH"
cp configs/sshd_config "${ROOTFS}/etc/ssh/sshd_config"

echo ">>> Removing pre-generated SSH host keys"
rm -f "${ROOTFS}"/etc/ssh/ssh_host_*

echo ">>> Setting up first-boot host key regeneration"
cp configs/firstboot.sh "${ROOTFS}/etc/rc.local"
chmod +x "${ROOTFS}/etc/rc.local"

echo ">>> Enabling SSH service"
chroot "${ROOTFS}" systemctl enable ssh

echo ">>> Setting root password"
echo "root:root" | chroot "${ROOTFS}" chpasswd

echo ">>> Setting hostname"
echo "debian-lxc" > "${ROOTFS}/etc/hostname"

echo ">>> Cleaning up apt cache"
chroot "${ROOTFS}" apt-get clean
rm -rf "${ROOTFS}/var/lib/apt/lists/"*

OUTFILE="${OUTPUT_DIR}/debian-13-ssh_${VERSION}_amd64.tar.xz"
echo ">>> Creating tarball: ${OUTFILE}"
tar -cJf "${OUTFILE}" -C "${ROOTFS}" .

SIZE=$(stat -c%s "${OUTFILE}")
echo ">>> Done: ${OUTFILE} ($(numfmt --to=iec ${SIZE}))"
