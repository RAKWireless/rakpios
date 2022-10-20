#!/bin/bash -e

on_chroot << EOF

# Generic python modules
pip3 install adafruit-blinka==7.1.1
pip3 install adafruit-circuitpython-atecc==1.2.9
pip3 install numpy==1.22.3

# Dependecies for OLED script
pip3 install adafruit-circuitpython-ssd1306==2.12.4
pip3 install pillow==9.0.1
pip3 install netifaces==0.11.0
pip3 install psutil==5.9.0

# Add FIRST_USER_NAME user to docker group
adduser $FIRST_USER_NAME docker

# Configure Network Manager
sed -i "s/managed=false/managed=true/g" "/etc/NetworkManager/NetworkManager.conf"
echo "denyinterfaces wlan0" >> "/etc/dhcpcd.conf"
echo "denyinterfaces wlan1" >> "/etc/dhcpcd.conf"
systemctl enable NetworkManager

# Create an alias for current user so that docker-compose points to docker compose
echo 'alias docker-compose="docker compose"' >>/home/$FIRST_USER_NAME/.bashrc

EOF


