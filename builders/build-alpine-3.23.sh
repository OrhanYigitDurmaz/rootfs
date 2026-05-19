#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: $0 <VERSION>}"
OUTPUT_DIR="$(pwd)/output"
ROOTFS=$(mktemp -d)
CACHE_DIR="/tmp/alpine-cache"
trap "rm -rf ${ROOTFS}" EXIT

mkdir -p "${OUTPUT_DIR}" "${CACHE_DIR}"

MIRROR="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/x86_64"

echo ">>> Finding latest Alpine 3.23 minirootfs"
TARBALL=$(curl -sL "${MIRROR}/" | grep -oP 'alpine-minirootfs-3\.23\.\d+-x86_64\.tar\.gz' | sort -V | tail -1)

if [ -z "${TARBALL}" ]; then
    echo "::error::Could not find Alpine 3.23 minirootfs tarball"
    exit 1
fi

echo ">>> Using: ${TARBALL}"

if [ ! -f "${CACHE_DIR}/${TARBALL}" ]; then
    echo ">>> Downloading ${MIRROR}/${TARBALL}"
    wget -q -O "${CACHE_DIR}/${TARBALL}" "${MIRROR}/${TARBALL}"
else
    echo ">>> Using cached ${TARBALL}"
fi

echo ">>> Extracting rootfs"
tar -xzf "${CACHE_DIR}/${TARBALL}" -C "${ROOTFS}"

echo ">>> Configuring Alpine repositories"
cat > "${ROOTFS}/etc/apk/repositories" <<EOF
https://dl-cdn.alpinelinux.org/alpine/v3.23/main
https://dl-cdn.alpinelinux.org/alpine/v3.23/community
EOF

echo ">>> Installing OpenSSH server"
chroot "${ROOTFS}" apk add --no-cache openssh openrc

echo ">>> Configuring SSH"
cp configs/sshd_config "${ROOTFS}/etc/ssh/sshd_config"
sed -i 's/^UsePAM yes/UsePAM no/' "${ROOTFS}/etc/ssh/sshd_config"

echo ">>> Removing pre-generated SSH host keys"
rm -f "${ROOTFS}"/etc/ssh/ssh_host_*

echo ">>> Setting up first-boot host key regeneration"
mkdir -p "${ROOTFS}/etc/local.d"
cp configs/firstboot.sh "${ROOTFS}/etc/local.d/firstboot.start"
chmod +x "${ROOTFS}/etc/local.d/firstboot.start"

echo ">>> Enabling services"
chroot "${ROOTFS}" rc-update add sshd default
chroot "${ROOTFS}" rc-update add local default

echo ">>> Setting root password"
echo "root:root" | chroot "${ROOTFS}" chpasswd

echo ">>> Setting hostname"
echo "alpine-lxc" > "${ROOTFS}/etc/hostname"

OUTFILE="${OUTPUT_DIR}/alpine-3.23-ssh_${VERSION}_amd64.tar.xz"
echo ">>> Creating tarball: ${OUTFILE}"
tar -cJf "${OUTFILE}" -C "${ROOTFS}" .

SIZE=$(stat -c%s "${OUTFILE}")
echo ">>> Done: ${OUTFILE} ($(numfmt --to=iec ${SIZE}))"
