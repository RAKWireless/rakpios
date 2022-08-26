#!/bin/bash -e

install -m 644 files/docker.list "${ROOTFS_DIR}/etc/apt/sources.list.d/"
sed -i "s/RELEASE/${RELEASE}/g" "${ROOTFS_DIR}/etc/apt/sources.list.d/docker.list"
sed -i "s/ARCH/${ARCH}/g" "${ROOTFS_DIR}/etc/apt/sources.list.d/docker.list"

on_chroot apt-key add - < files/docker.gpg.key
on_chroot << EOF
apt update
apt dist-upgrade -y
apt install -y apt-transport-https ca-certificates lsb-release 
EOF
