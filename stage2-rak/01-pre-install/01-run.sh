#!/bin/bash -e

on_chroot << EOF

# Add FIRST_USER_NAME user to docker group
adduser $FIRST_USER_NAME docker

# Configure Network Manager
sed -i "s/managed=false/managed=true/g" "/etc/NetworkManager/NetworkManager.conf"
systemctl enable NetworkManager

# Create an alias for current user so that docker-compose points to docker compose
echo 'alias docker-compose="docker compose"' >>/home/$FIRST_USER_NAME/.bashrc

EOF


