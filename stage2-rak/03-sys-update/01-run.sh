#!/bin/bash -e

# Add rakuid
cp files/rc.local "${ROOTFS_DIR}/etc/rc.local"
cp files/rakuid "${ROOTFS_DIR}/bin/rakuid"
cp files/get_RAKUID "${ROOTFS_DIR}/bin/get_RAKUID"

#Add oled script
cp files/oled "${ROOTFS_DIR}/bin/oled"

# Add scripts
cp files/portainer "${ROOTFS_DIR}/bin/portainer"

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

# Force user to change password after first login
on_chroot << EOF
passwd -e $FIRST_USER_NAME
EOF

# Update MOTD
cp files/update-motd.d/* "${ROOTFS_DIR}/etc/update-motd.d/"
rm -rf "${ROOTFS_DIR}/etc/update-motd.d/10-uname"

