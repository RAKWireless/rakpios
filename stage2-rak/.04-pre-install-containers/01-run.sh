#!/bin/bash -e

# Create a directory structure to store run once scripts
on_chroot << EOF
mkdir -p /etc/local/runonce.d/ran/
EOF

# Copy portainer.sh.sample to /etc/local/runonce.d/
# This is where you store the actual services
cp files/run-once-services/portainer.sh.sample "${ROOTFS_DIR}/etc/local/runonce.d/"
cp files/run-once-services/docker-compose.sh.sample "${ROOTFS_DIR}/etc/local/runonce.d/"

# copy the runonce script
cp files/runonce "${ROOTFS_DIR}/usr/local/bin/"
# copy the rc.local script
cp files/rc.local "${ROOTFS_DIR}/etc/rc.local"

# configure the premission for the service scripts
on_chroot << EOF
chown ${FIRST_USER_NAME}:${FIRST_USER_NAME} /etc/local/runonce.d/portainer.sh.sample
chmod +x /etc/local/runonce.d/portainer.sh.sample

chown ${FIRST_USER_NAME}:${FIRST_USER_NAME} /etc/local/runonce.d/docker-compose.sh.sample
chmod +x /etc/local/runonce.d/docker-compose.sh.sample

EOF
