#!/bin/bash -e

ARCH=${ARCH:-"arm64"}
export ARCH

KERNEL_TAG=${KERNEL_TAG:-"rpi-5.15.y"}
export KERNEL_TAG

pushd files >> /dev/null

if [[ ${KERNEL_BUILD:-0} -eq 1 ]]; then

    echo "Building kernel"
    chmod +x ./make

    # Checkout the kernel
    ./make init

    # Apply patches
    if [ -f patches/${KERNEL_TAG}.patch ]; then
        echo "Applying ${KERNEL_TAG}.patch ..."
        pushd linux >> /dev/null
        git apply ../patches/${KERNEL_TAG}.patch
        popd >> /dev/null
    fi

    # Apply configuration
    ./make default
    cp -f ${ARCH}.config linux/.config

    # Build
    ./make build
    
    # Copy kernel and modules to image
    ./make copy ${ROOTFS_DIR}
    
    # Create zipped version we can use as cache
    ./make zip

    # Clean up
    rm -rf linux modules

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
wget https://anduin.linuxfromscratch.org/sources/linux-firmware/intel/ibt-0041-0041.sfi
wget https://anduin.linuxfromscratch.org/sources/linux-firmware/intel/ibt-0041-0041.ddc

mkdir firmware
for package in `ls *.tgz`; do 
    tar -xzf $package -C firmware/
done
cp firmware/*/iwlwifi-*.ucode "${ROOTFS_DIR}/lib/firmware"
cp ibt-0041-0041.* "${ROOTFS_DIR}/lib/firmware/intel"
rm -rf iwlwifi* firmware ibt-0041-0041.*
