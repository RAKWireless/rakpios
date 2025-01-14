#!/bin/bash -e

# Install docker
on_chroot << EOF
unset VERSION
curl -fsSL https://get.docker.com | sh
usermod -aG docker $FIRST_USER_NAME
echo 'alias docker-compose="docker compose"' >>/home/$FIRST_USER_NAME/.bashrc
EOF


