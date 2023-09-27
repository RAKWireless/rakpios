#!/bin/bash -e

on_chroot << EOF
mkdir -p /usr/local/share/docker-images
mkdir -p /etc/local/runonce.d
EOF

# Pull and compress docker images
if [ $DOCKER_EMBED_IMAGES -eq 1 ]; then

    service docker start
    sleep 1

    IMAGES=$( cat files/runonce.d/*.yml | grep "^\s*image:" | sed 's/^\s*image:\s*//' )
    for IMAGE in $IMAGES; do
        FILENAME=$(echo "${IMAGE}" | sed 's/[^[:alnum:]]\+/_/g')
        docker pull -q $IMAGE
        docker save $IMAGE > "${ROOTFS_DIR}/usr/local/share/docker-images/$FILENAME.tar"
    done

fi

# Copy the runonce main and custom scripts
cp files/runonce "${ROOTFS_DIR}/usr/local/bin/"
cp files/runonce.d/* "${ROOTFS_DIR}/etc/local/runonce.d/"

# Update rc.local script to run runonce
on_chroot << EOF
sed 's/^exit/# Run once after reboot\n\/usr\/local\/bin\/runonce\n\nexit/' -i /etc/rc.local 
EOF

# Configure the premissions for the main script and the service scripts
on_chroot << EOF
chown ${FIRST_USER_NAME}:${FIRST_USER_NAME} /etc/local/runonce.d/*
chmod +x /etc/local/runonce.d/*.sh
chmod +x /usr/local/bin/runonce
EOF
