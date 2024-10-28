#!/bin/bash -e

# Set wwan0 to raw IP mode when using BG96
install -m 755 files/wwan0.sh "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/pre-up.d/"

# Add oled script
install -m 644 files/oled.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 755 files/oled "${ROOTFS_DIR}/usr/local/bin/"
on_chroot << EOF
systemctl enable oled
EOF

# Add portainer up script
install -m 755 files/portainer "${ROOTFS_DIR}/usr/local/bin/"

# Add rakpios-cli
on_chroot << EOF
runuser -l ${FIRST_USER_NAME} -c 'mkdir $HOME/.local/lib ; curl https://raw.githubusercontent.com/RAKWireless/rakpios-cli/main/rakpios-cli -sSf | bash -s -- --install --silent'
EOF

# Add mioty-cli
on_chroot << EOF
runuser -l ${FIRST_USER_NAME} -c 'curl https://raw.githubusercontent.com/RAKWireless/mioty-cli/master/rakpios-cli -sSf | bash -s -- install'
EOF

# Add wisblock USB rules
install -m 644 files/99-wisblock.rules "${ROOTFS_DIR}/etc/udev/rules.d/"

# Add create_ap service
install -m 644 files/create-ap.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 755 files/create-ap "${ROOTFS_DIR}/usr/local/bin/"
install -d "${ROOTFS_DIR}/usr/local/share/wifi-connect/"
tar xvzf files/wifi-connect-v4.4.6-linux-aarch64-rakwireless.tar.gz -C files/
install -m 755 files/wifi-connect-v4.4.6-linux-aarch64-rakwireless/wifi-connect "${ROOTFS_DIR}/usr/local/sbin/"
cp -r files/wifi-connect-v4.4.6-linux-aarch64-rakwireless/ui "${ROOTFS_DIR}/usr/local/share/wifi-connect/"
rm -rf files/wifi-connect-v4.4.6-linux-aarch64-rakwireless
on_chroot << EOF
systemctl enable create-ap
EOF

# Update MOTD
cp files/update-motd.d/* "${ROOTFS_DIR}/etc/update-motd.d/"
rm -rf "${ROOTFS_DIR}/etc/update-motd.d/10-uname"

