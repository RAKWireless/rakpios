#!/bin/bash -e

# Add rakuid
cp files/rc.local "${ROOTFS_DIR}/etc/rc.local"
cp files/rakuid "${ROOTFS_DIR}/bin/rakuid"
cp files/get_RAKUID "${ROOTFS_DIR}/bin/get_RAKUID"

#Add oled script
cp files/oled "${ROOTFS_DIR}/bin/oled"

# Add portainer up script
cp files/portainer "${ROOTFS_DIR}/bin/portainer"

# Add rakpios-cli
on_chroot << EOF
runuser -l ${FIRST_USER_NAME} -c 'curl https://raw.githubusercontent.com/RAKWireless/rakpios-cli/main/rakpios-cli -sSf | bash -s -- --install --silent'
EOF

# Update config.txt
cp files/config.txt "${ROOTFS_DIR}/boot/"

# Enable modules
cp files/modules "${ROOTFS_DIR}/etc/modules"
        
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

# add create-AP service
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


# Force user to change password after first login
on_chroot << EOF
passwd -e $FIRST_USER_NAME
echo "$FIRST_USER_NAME ALL=(ALL) PASSWD: ALL" > /etc/sudoers.d/010_pi-nopasswd
EOF

# Update MOTD
cp files/update-motd.d/* "${ROOTFS_DIR}/etc/update-motd.d/"
rm -rf "${ROOTFS_DIR}/etc/update-motd.d/10-uname"

# Set wwan0 to raw IP mode when using BG96
cp files/wwan0.sh "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/pre-up.d/"

# Disable dhcpcd because NetworkManager already has a DHCP client
on_chroot << EOF
systemctl disable dhcpcd
EOF
