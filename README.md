# RAKPiOS

Tool used to create RAKPiOS images based on pi-gen (https://github.com/RPI-Distro/pi-gen.git).

The RAKPiOS image differs from the stock Raspberry Pi OS in:

* Custom kernel with support for WiFi Next Gen AGN
* Overlays for existing components in RAK7391
* Docker installed by default
* Brings up a WiFi Access Point if no other connection is active
* Custom MOTD
* SSH, I2C and SPI enabled by default
* Set of utilities
  * OLED script to leverage a connected SSD1306 OLED screen to display system metrics
  * rakpios-cli to manage network and docker images
* Default user (`rak`) and password (`changeme`), forces user to create new password on first login

# Notes about RAKPiOS specific features

Changes to the default Raspberry Pi OS image are defined on the `stage2-rak` stage. This is used to build a customized image for RAK WisGate Developer products. The stage will make some changes to the systems, including pre-installing docker and other tools, adding new kernel modules, updating system information, and adding some new features tailored for RAK WisGate Developer products.

## Getting started with building using stage2-rak

As mentioned in the original `README.md` (see https://github.com/RPI-Distro/pi-gen.git), users can define a variable called `STAGE_LIST` in the configuration file to change the order of building stages. In the `default_config` file, variable `STAGE_LIST` is set to `stage0 stage1 stage2 stage2-rak`, then instead of working through the numeric stages in order, this list will be followed. 
RAKPiOS is a *lite* system, thus the build will skip stage 3, stage 4, and stage 5 which are only for a desktop system with a graphical user interface.

## A simple example for building RAKPiOS image

We defined some original configuration tags and also introduced some custom configuration tags in the `config_rak` file.

```
ARCH=arm64
NAME="rakpios"
VERSION=0.8.0
RELEASE=bookworm

IMG_NAME="${NAME}-${VERSION}-${ARCH}"
PI_GEN_RELEASE="${NAME}-${VERSION}-${RELEASE}"
TARGET_HOSTNAME="${NAME}"
IMG_DATE=$( date +%Y%m%d )
ARCHIVE_FILENAME="${IMG_DATE}-${IMG_NAME}"
FIRST_USER_NAME=rak
FIRST_USER_PASS=changeme
DISABLE_FIRST_BOOT_USER_RENAME=1
ENABLE_SSH=1
STAGE_LIST="stage0 stage1 stage2 stage2-rak"

PI_GEN_REPO=https://github.com/RAKWireless/rakpios
KERNEL_BUILD=0
KERNEL_CACHED=1
KERNEL_TAG=rpi-6.1.y

```

For more details about the original configurations, please check the original `README.md` . For custom configuration tags, now you can define whether you want to build the kernel (`KERNEL_BUILD` and `KERNEL_TAG` variables), use the cached image (`KERNEL_CACHED` variable) or just leave it to the official kernel. 
If `KERNEL_BUILD` is set to 1 but no `KERNEL_TAG` is defined then it defaults to the HEAD of the `rpi-6.1.y` branch. But please mind that some specific kernel patches (like GPIO Expander support) will not be applied since they are version-dependent.
The final step is to launch the build.sh script：

```bash
sudo ./build.sh -c config_rak
```

or, you can use docker to perform the build:

```bash
./build-docker.sh -c config_rak
```

Please check the original README.md to see how to skip stages and also how to continue the build after a failure.

## How the stage2-rak stage works

There are a number of different directories in the `stage2-rak` directory:

- **00-base** - Updates and installs new packages, new config.txt, sets up custom firstboot script
  
- **01-docker** - Installs docker, docker compose plugin, and add user **rak** user to docker group.
  
- **02-kernel** - A kernel builder allows you to cross-build a kernel that is tailored exactly to your requirements.
  
- **03-utils** - Installs several scripts and utilities: boot AP, OLED script, portainer, MOTD, and so on.   

## Notice

- The default login credentials for the pre-built image are username: `rak` and password: `changeme`. Please note that it is important to change the default password upon first login to enhance security.
  
- In the case of WiFi-enabled CM4 modules and Raspberry Pi, the image will automatically create an access point when the device boots and no other connectivity options are enabled. This feature is based on [WiFi-connect](https://github.com/balena-os/wifi-connect) developed by Balena.
  
  This access point, named `RAK_XXXX` (where `XXXX` represents the last four digits of the `eth0` MAC address), enables users to configure an existing connection. The access point is secured with the password `rakwireless`. After connecting to the access point from a mobile phone or laptop, the captive portal will be detected and the web page will automatically open. In the event that the captive portal does not automatically redirect, please browse to `192.168.230.1` to access the captive portal.
