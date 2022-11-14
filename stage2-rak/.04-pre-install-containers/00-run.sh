#!/bin/bash -e


# Copy docker-compose files
cp -r files/docker-compose-files/ "${ROOTFS_DIR}/usr/local/etc/"

# You can save the compressed images to the stage2-rak/.04-pre-install-containers/files/images,
# and then just do local copy and paste
# cp -r files/images "${ROOTFS_DIR}/usr/local/etc/"

# You can choose to just download the example compressed file we provided, here is some examples
# Basicstation packet forwarder
# wget -O ./files/images/image-tar-basicstation.tar https://github.com/Sheng2216/saved-images-for-rakpios/releases/download/v1.0.1/image-tar-basicstation.tar

# Portainer
wget -O ./files/images/image-tar-portainer.tar https://github.com/Sheng2216/saved-images-for-rakpios/releases/download/v1.0.1/image-tar-portainer.tar

# Required images for The Things Stack, including postgres, redis, and stack
# wget -O ./files/images/image-tar-tts-postgres.tar https://github.com/Sheng2216/saved-images-for-rakpios/releases/download/v1.0.1/image-tar-tts-postgres.tar
# wget -O ./files/images/image-tar-tts-redis.tar https://github.com/Sheng2216/saved-images-for-rakpios/releases/download/v1.0.1/image-tar-tts-redis.tar
# wget -O ./files/images/image-tar-tts-stack.tar https://github.com/Sheng2216/saved-images-for-rakpios/releases/download/v1.0.1/image-tar-tts-stack.tar

# UDP packet forwarder
wget -O ./files/images/image-tar-udp.tar https://github.com/Sheng2216/saved-images-for-rakpios/releases/download/v1.0.1/image-tar-udp.tar

# You can also choose to manually save the compressed images to the stage2-rak/.04-pre-install-containers/files/images, instead of downloading the compressed image

# Copy the compressed images to the RAKPiOS
cp -r files/images "${ROOTFS_DIR}/usr/local/etc/"
