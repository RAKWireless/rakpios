#!/bin/bash -e

# Update config.txt for RAK6421
install -m 755 files/config.txt "${ROOTFS_DIR}/boot/firmware/"

# Remove serial console from cmdline.txt to free up serial port for RAK12501 GPS module
sed -i "s/console=serial0,115200 //g" "${ROOTFS_DIR}/boot/firmware/cmdline.txt"

# Install meshtasticd
on_chroot << EOF
# Add Meshtastic repository
echo 'deb http://download.opensuse.org/repositories/network:/Meshtastic:/beta/Debian_12/ /' > /etc/apt/sources.list.d/network:Meshtastic:beta.list

# Add GPG key
curl -fsSL https://download.opensuse.org/repositories/network:Meshtastic:beta/Debian_12/Release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/network_Meshtastic_beta.gpg

# Update and install meshtasticd
apt update
apt install -y meshtasticd
EOF

# Install Python CLI
on_chroot << EOF
pip3 install --break-system-packages --upgrade pytap2
pip3 install --break-system-packages --upgrade "meshtastic[cli]"
EOF

# Configure meshtasticd - uncomment Webserver Port
on_chroot << EOF
sed -i 's/^#  Port: 9443/  Port: 9443/' /etc/meshtasticd/config.yaml
EOF

