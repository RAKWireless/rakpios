#!/bin/bash -e

# Add custom firstboot script
install -m 755 files/firstboot-rak "${ROOTFS_DIR}/usr/bin/"
install -d 766 "${ROOTFS_DIR}/usr/share/firstboot.d/"
install -m 755 files/firstboot.d/* "${ROOTFS_DIR}/usr/share/firstboot.d/"
sed -i "s|main$|main\nfirstboot-rak\n|" "${ROOTFS_DIR}/usr/lib/raspberrypi-sys-mods/firstboot"

# Update config.txt
install -m 755 files/config.txt "${ROOTFS_DIR}/boot/firmware/"

# Enable I2C
on_chroot << EOF
echo "i2c-dev" >> /etc/modules
EOF

# Force user to change password after first login
on_chroot << EOF
passwd -e $FIRST_USER_NAME
echo "$FIRST_USER_NAME ALL=(ALL) PASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd
EOF

# Configure Network Manager
on_chroot << EOF
sed -i "s/managed=false/managed=true/g" "/etc/NetworkManager/NetworkManager.conf"
EOF

# Update os-release file
cat > "${ROOTFS_DIR}/usr/lib/os-release" << EOL
PRETTY_NAME="RAK PiOS GNU/Linux (${RELEASE})"
NAME="RAK PiOS GNU/Linux"
VERSION_ID="${IMG_NAME}"
VERSION="${RELEASE}"
ID="rakpios"
ID_LIKE="debian"
HOME_URL="http://www.rakwireless.com/"
SUPPORT_URL="${PI_GEN_REPO}"
BUG_REPORT_URL="${PI_GEN_REPO}/issues"
COMMIT_SHA="${COMMIT_HASH:-$(git rev-parse --short HEAD)}"
COMMIT_DATE="${COMMIT_DATE:-$(git log -1 --format=%ad --date=short)}"
IMAGE_DATE="$(date +%Y-%m-%d)"
EOL

