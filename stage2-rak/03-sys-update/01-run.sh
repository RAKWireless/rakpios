#!/bin/bash -e

# Add proper resize partition to firstboot script
sed -i "s|^  fix_partuuid|  fix_partuuid\n  raspi-config --expand-rootfs\n  raspi-config nonint do_i2c 0\n|" "${ROOTFS_DIR}/usr/lib/raspberrypi-sys-mods/firstboot"

# Update config.txt
install -m 644 files/config.txt "${ROOTFS_DIR}/boot/firmware/"

# Enable modules
install -m 644 files/modules "${ROOTFS_DIR}/etc/"
        
# Update os-release file
cat > "${ROOTFS_DIR}/etc/os-release" << EOL
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

# Force user to change password after first login
on_chroot << EOF
passwd -e $FIRST_USER_NAME
echo "$FIRST_USER_NAME ALL=(ALL) PASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd
EOF

# Set wwan0 to raw IP mode when using BG96
cp files/wwan0.sh "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/pre-up.d/"

# Add rakuid utility
cp files/atecc-util_0.4.11_arm64.deb "${ROOTFS_DIR}/tmp/"
on_chroot << EOF
apt install /tmp/atecc-util_0.4.11_arm64.deb
EOF
rm -f "${ROOTFS_DIR}/tmp/atecc-util_0.4.11_arm64.deb"
install -m 755 files/rc.local "${ROOTFS_DIR}/etc/"
install -m 755 files/rakuid "${ROOTFS_DIR}/usr/bin/"

# Add oled script
install -m 755 files/oled "${ROOTFS_DIR}/usr/bin/"

# Add portainer up script
install -m 755 files/portainer "${ROOTFS_DIR}/usr/bin/"

# Add rakpios-cli
on_chroot << EOF
runuser -l ${FIRST_USER_NAME} -c 'curl https://raw.githubusercontent.com/RAKWireless/rakpios-cli/main/rakpios-cli -sSf | bash -s -- --install --silent'
EOF

# Add create_ap service
cp files/create-ap.service "${ROOTFS_DIR}/etc/systemd/system/"
cp files/create-ap "${ROOTFS_DIR}/usr/local/bin/"
tar xvzf files/wifi-connect-v4.4.6-linux-aarch64-rakwireless.tar.gz -C files/
cp files/wifi-connect-v4.4.6-linux-aarch64-rakwireless/wifi-connect "${ROOTFS_DIR}/usr/local/sbin/"
on_chroot << EOF
mkdir -p /usr/local/share/wifi-connect/
EOF
cp -r files/wifi-connect-v4.4.6-linux-aarch64-rakwireless/ui "${ROOTFS_DIR}/usr/local/share/wifi-connect/"
on_chroot << EOF
systemctl daemon-reload
systemctl enable create-ap
EOF

# Update MOTD
cp files/update-motd.d/* "${ROOTFS_DIR}/etc/update-motd.d/"
rm -rf "${ROOTFS_DIR}/etc/update-motd.d/10-uname"

