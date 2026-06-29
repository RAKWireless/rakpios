#!/bin/bash -e

# Update config.txt for RAK6421
install -m 755 files/config.txt "${ROOTFS_DIR}/boot/firmware/"

install -d -o 1000 -g 1000 -m 755 \
	"${ROOTFS_DIR}/home/${FIRST_USER_NAME}/meshmonitor"
install -m 644 -o 1000 -g 1000 \
	files/meshmonitor-docker-compose.yaml \
	"${ROOTFS_DIR}/home/${FIRST_USER_NAME}/meshmonitor/"
install -m 755 -o 1000 -g 1000 \
	files/setup.sh \
	"${ROOTFS_DIR}/home/${FIRST_USER_NAME}/meshmonitor/"

# Disable serial console at image build time so GPS can use UART out of the box.
# config.txt already sets enable_uart=1; this removes console=serial0 from cmdline.
# setup.sh Phase 1 runs raspi-config for the same settings (idempotent if re-run later).
sed -i "s/console=serial0,115200 //g" "${ROOTFS_DIR}/boot/firmware/cmdline.txt"

# Install meshtasticd and monitoring stack packages.
on_chroot << EOF
set -e

export DEBIAN_FRONTEND=noninteractive

# Do not let service packages try to start daemons inside the chroot.
cat > /usr/sbin/policy-rc.d <<'POLICYEOF'
#!/bin/sh
exit 101
POLICYEOF
chmod 755 /usr/sbin/policy-rc.d

# Add Meshtastic repository
echo 'deb http://download.opensuse.org/repositories/network:/Meshtastic:/alpha/Debian_12/ /' > /etc/apt/sources.list.d/network:Meshtastic:alpha.list

# Add GPG key
curl -fsSL https://download.opensuse.org/repositories/network:Meshtastic:alpha/Debian_12/Release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/network_Meshtastic_alpha.gpg


apt-get update
apt-get install -y meshtasticd

rm -f /usr/sbin/policy-rc.d
EOF

# Install Python CLI
on_chroot << EOF
pip3 install --break-system-packages --upgrade pytap2
pip3 install --break-system-packages --upgrade "meshtastic[cli]"
EOF

on_chroot << EOF
systemctl enable meshtasticd
raspi-config nonint do_wifi_country US
EOF
