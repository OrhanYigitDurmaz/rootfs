#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: $0 <VERSION>}"
OUTPUT_DIR="$(pwd)/output"

mkdir -p "${OUTPUT_DIR}"

OUTFILE="${OUTPUT_DIR}/alpine-edge-ssh_${VERSION}_amd64.tar.xz"

echo ">>> Downloading alpine-make-rootfs"
wget -q -O /tmp/alpine-make-rootfs https://raw.githubusercontent.com/alpinelinux/alpine-make-rootfs/v0.8.1/alpine-make-rootfs
chmod +x /tmp/alpine-make-rootfs

echo ">>> Building Alpine Edge rootfs"
/tmp/alpine-make-rootfs \
    --branch edge \
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


        # Configure console autologin
        install -d /usr/sbin
        cat > /usr/sbin/autologin <<'AUTOLOGIN'
#!/bin/sh
exec /bin/login -f root
AUTOLOGIN
        chmod +x /usr/sbin/autologin
        sed -i 's|^tty1::.*|tty1::respawn:/sbin/getty -n -l /usr/sbin/autologin 38400 tty1|' /etc/inittab
        grep -q '^::respawn:.*console' /etc/inittab && \
            sed -i 's|^::respawn:.*console.*|::respawn:/sbin/getty -n -l /usr/sbin/autologin 0 console|' /etc/inittab || \
            echo '::respawn:/sbin/getty -n -l /usr/sbin/autologin 0 console' >> /etc/inittab

        # Set hostname
        echo 'alpine-edge-lxc' > /etc/hostname
SHELL

SIZE=$(stat -c%s "${OUTFILE}")
echo ">>> Done: ${OUTFILE} ($(numfmt --to=iec ${SIZE}))"
