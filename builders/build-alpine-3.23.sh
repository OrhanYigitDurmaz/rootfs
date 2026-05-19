#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: $0 <VERSION>}"
OUTPUT_DIR="$(pwd)/output"

mkdir -p "${OUTPUT_DIR}"

OUTFILE="${OUTPUT_DIR}/alpine-3.23-ssh_${VERSION}_amd64.tar.xz"

echo ">>> Downloading alpine-make-rootfs"
wget -q -O /tmp/alpine-make-rootfs https://raw.githubusercontent.com/alpinelinux/alpine-make-rootfs/v0.8.1/alpine-make-rootfs
chmod +x /tmp/alpine-make-rootfs

echo ">>> Building Alpine 3.23 rootfs"
/tmp/alpine-make-rootfs \
    --branch v3.23 \
    --packages 'apk-tools openssh openrc' \
    --script-chroot \
    "${OUTFILE}" - <<SHELL
        # Configure SSH
        install -m 644 /mnt/configs/sshd_config /etc/ssh/sshd_config
        sed -i 's/^UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

        # Remove pre-generated SSH host keys
        rm -f /etc/ssh/ssh_host_*

        # First-boot host key regeneration
        install -m 755 /mnt/configs/firstboot.sh /etc/local.d/firstboot.start

        # Enable services
        rc-update add sshd default
        rc-update add local default

        # Set root password
        echo 'root:root' | chpasswd

        # Set hostname
        echo 'alpine-lxc' > /etc/hostname
SHELL

SIZE=$(stat -c%s "${OUTFILE}")
echo ">>> Done: ${OUTFILE} ($(numfmt --to=iec ${SIZE}))"
