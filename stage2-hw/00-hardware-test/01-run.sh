#!/bin/bash -e

#Copy test script 
cp -r files/hardware-test "${ROOTFS_DIR}/home/rak"
chown -R rak:rak "${ROOTFS_DIR}/home/rak/hardware-test"

# Update config.txt
cp files/config.txt "${ROOTFS_DIR}/boot/"


