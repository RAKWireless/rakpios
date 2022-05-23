#!/bin/bash -e

on_chroot << EOF

pip3 install pyserial
pip3 install smbus
pip3 install smbus2
pip3 install adafruit-ads1x15
pip3 install adafruit-circuitpython-bme280
pip3 install RPi.GPIO
pip3 install gpiod
pip3 install adafruit-circuitpython-shtc3
pip3 install psutil
pip3 install iperf3
pip3 install adafruit-extended-bus
pip3 install adafruit-circuitpython-atecc
pip3 install luma.core
pip3 install luma.oled
pip3 install LoRaRF 

EOF

#Copy test script 
cp -r files/hardware-test "${ROOTFS_DIR}/home/rak"
chown -R rak:rak "${ROOTFS_DIR}/home/rak/hardware-test"
# Update config.txt
cp files/config.txt "${ROOTFS_DIR}/boot/"


