#!/bin/bash -e

# Cloud-Init for trixie (filesystem expansion on first boot)
install -v -m 644 files/meta-data "${ROOTFS_DIR}/boot/firmware/meta-data"
install -v -m 644 files/user-data "${ROOTFS_DIR}/boot/firmware/user-data"
# network-config intentionally not installed (conflicts with NetworkManager)

# Add custom firstboot script
#install -m 755 files/firstboot-rak "${ROOTFS_DIR}/usr/bin/"
#install -d "${ROOTFS_DIR}/usr/share/firstboot.d/"
#install -m 755 files/firstboot.d/* "${ROOTFS_DIR}/usr/share/firstboot.d/"
#sed -i "s|main$|main\nfirstboot-rak\n|" "${ROOTFS_DIR}/usr/lib/raspberrypi-sys-mods/firstboot"

# Build overlays
dtc -I dts -O dtb files/rak7391.dts -o files/rak7391.dtbo
install -m 755 files/rak7391.dtbo "${ROOTFS_DIR}/boot/firmware/overlays/"

# Update config.txt
install -m 755 files/config.txt "${ROOTFS_DIR}/boot/firmware/"

# Add carrier board detection (fills in the RAK BOARD block in config.txt)
install -m 755 files/rak-board-detect "${ROOTFS_DIR}/usr/local/bin/"
install -m 644 files/rak-board-detect.service "${ROOTFS_DIR}/etc/systemd/system/"
on_chroot << EOF
systemctl enable rak-board-detect
EOF

# Enable SSH
on_chroot << EOF
sudo raspi-config nonint do_ssh 0
EOF

# Enable I2C
on_chroot << EOF
echo "i2c-dev" >> /etc/modules
sudo raspi-config nonint do_i2c 0
EOF

# Enable SPI
on_chroot << EOF
sudo raspi-config nonint do_spi 0
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

# Enable Wifi
on_chroot << EOF
raspi-config nonint do_wifi_country GB
EOF

# Update os-release file
cat > "${ROOTFS_DIR}/usr/lib/os-release" << EOL
PRETTY_NAME="${NAME} ${VERSION} (${RELEASE})"
NAME="${NAME}"
VERSION="${VERSION}"
VERSION_ID="${NAME,,}-${VERSION}-${ARCH}"
VERSION_CODENAME="${RELEASE}"
BUILD_ID="${IMG_DATE}"
ID="${NAME,,}"
ID_LIKE="debian"
VARIANT="${ARCH}"
HOME_URL="http://www.rakwireless.com/"
SUPPORT_URL="${PI_GEN_REPO}"
BUG_REPORT_URL="${PI_GEN_REPO}/issues"
COMMIT_SHA="${COMMIT_HASH:-$(git rev-parse --short HEAD)}"
COMMIT_DATE="${COMMIT_DATE:-$(git log -1 --format=%ad --date=short)}"
IMAGE_DATE="$(date +%Y-%m-%d)"
EOL

