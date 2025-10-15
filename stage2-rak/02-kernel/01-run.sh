#!/bin/bash -e

export ARCH=${ARCH:-"arm64"}
export KERNEL_TAG=${KERNEL_TAG:-"rpi-6.12.y"}

pushd files >> /dev/null

if [[ ${KERNEL_BUILD:-0} -eq 1 ]]; then

    echo "Building kernel"
    chmod +x ./make

    # Checkout the kernel
    ./make init

    # Apply patches
    if [ -d patches/${KERNEL_TAG} ]; then
        for PATCH in `ls patches/${KERNEL_TAG}/*.patch`; do
            echo "Applying ${PATCH} ..."
            ./make patch ${PATCH}
        done
    fi

    # Build images for CM4 and RPi5
    for MACHINE in cm4 rpi5; do 
    
        export MACHINE
        echo "Building kernel for ${MACHINE^^}"

        # Apply configuration
        ./make default
        if [[ "$MACHINE" == "rpi5" ]]; then
            ./make set CONFIG_LOCALVERSION \"-v8-16k-rak\"
        else
            ./make set CONFIG_LOCALVERSION \"-v8-rak\"
        fi
        ./make set CONFIG_IWLWIFI m
        ./make set CONFIG_IWLWIFI_LEDS y
        ./make set CONFIG_IWLMVM m 
        ./make set CONFIG_IWLWIFI_OPMODE_MODULAR y
        ./make set CONFIG_IWLWIFI_DEVICE_TRACING y

        # Build
        ./make build
        
        # Copy kernel and modules to image
        ./make copy ${ROOTFS_DIR}
        
        # Create zipped version we can use as cache
        ./make zip

    done

    # Clean up
    rm -rf linux modules

elif [[ ${KERNEL_CACHED:-1} -eq 1 ]]; then

    echo "Using cached kernel"
    for file in `ls *.kernel.zip`; do
        unzip -oq $file -d ${ROOTFS_DIR}
    done

else

    echo "Using default kernel"

fi

popd >> /dev/null

# Intel WiFi6 drivers (AX200, AX201 & AX210)
cp -r files/firmware/* "${ROOTFS_DIR}/lib/firmware/"