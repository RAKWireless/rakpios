#!/bin/bash -e

ARCH=${ARCH:-"arm64"}
export ARCH

pushd files >> /dev/null

if [[ ${KERNEL_BUILD:-0} -eq 1 ]]; then

    echo "Building kernel"
    chmod +x ./make
    ./make init
    ./make default
    cp -f ${ARCH}.config linux/.config
    ./make build
    #./make zip # this step creates a ZIP we can use as cache
    ./make copy ${ROOTFS_DIR}

elif [[ ${KERNEL_CACHED:-1} -eq 1 ]]; then

    echo "Using cached kernel"
    unzip -oq ${ARCH}.kernel.zip -d ${ROOTFS_DIR}

else

    echo "Using default kernel"

fi

popd >> /dev/null

# Intel WiFi6 drivers (AX200, AX201 & AX210)
# https://www.intel.com/content/www/us/en/support/articles/000005511/wireless.html
wget https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi-ty-59.601f3a66.0.tgz
wget https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi/iwlwifi-qu-48.13675109.0.tgz
wget https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi/iwlwifi-cc-46.3cfab8da.0.tgz
mkdir firmware
for package in `ls *.tgz`; do 
    tar -xzf $package -C firmware/
done
cp firmware/*/iwlwifi-*.ucode "${ROOTFS_DIR}/lib/firmware"
rm -rf iwlwifi* firmware
