#!/bin/bash -e

on_chroot << EOF

# Docker Compose
pip3 install docker-compose

# Generic python modules
pip3 install adafruit-blinka
pip3 install adafruit-circuitpython-atecc
pip3 install numpy

# Dependecies for OLED script
pip3 install adafruit-circuitpython-ssd1306
pip3 install pillow
pip3 install netifaces
pip3 install psutil

# Add rak user to docker group
adduser $FIRST_USER_NAME docker

# Configure Network Manager
sed -i "s/managed=false/managed=true/g" "/etc/NetworkManager/NetworkManager.conf"
echo "denyinterfaces wlan0" >> "/etc/dhcpcd.conf"

EOF

