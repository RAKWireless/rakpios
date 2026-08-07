# RAKPiOS

This document describes the differences of RAKPiOS with Raspberry Pi OS.

## Introduction

This tool is used to create RAKPiOS images, a custom image based on Raspberry Pi OS, which was in turn derived from the Raspbian project.

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

## RAKPiOS specific building stage

Changes to the default Raspberry Pi OS image are defined on the `stage2-rak` stage. This is used to build a customized image for RAK WisGate Developer products. The stage will make some changes to the systems, including pre-installing docker and other tools, adding new kernel modules, updating system information, and adding some new features tailored for RAK WisGate Developer products.

As mentioned in the original `README.md` (see https://github.com/RPI-Distro/pi-gen.git), users can define a variable called `STAGE_LIST` in the configuration file to change the order of building stages. In the `config_rak` file, variable `STAGE_LIST` is set to `stage0 stage1 stage2 stage2-rak`, then instead of working through the numeric stages in order, this list will be followed. 

RAKPiOS is a *lite* system, thus the build will skip stage 3, stage 4, and stage 5 which are only for a desktop system with a graphical user interface.

We defined some original configuration tags and also introduced some custom configuration tags in the `config_rak` file.

```
NAME="RAKPiOS"
VERSION=1.0.0
ARCH=arm64
RELEASE=trixie

IMG_NAME="${NAME,,}-${VERSION}-${ARCH}"
PI_GEN_RELEASE="${NAME,,}-${VERSION}-${RELEASE}"
TARGET_HOSTNAME="${NAME,,}"
IMG_DATE=$( date +%Y%m%d )
ARCHIVE_FILENAME="${IMG_DATE}-${IMG_NAME}"
FIRST_USER_NAME=rak
FIRST_USER_PASS=changeme
DISABLE_FIRST_BOOT_USER_RENAME=1
ENABLE_SSH=1
STAGE_LIST="stage0 stage1 stage2 stage2-rak"
DEPLOY_COMPRESSION=xz
PI_GEN_REPO=https://github.com/RAKWireless/rakpios

KERNEL_STRATEGY=default
KERNEL_TAG=rpi-6.12.y
```

For more details about the original configurations, please check the original `README.md` . For custom configuration tags, now you can define whether you want to build the kernel (set `KERNEL_STRATEGY` to `build` and `KERNEL_TAG` to the version to build), use the cached image (set `KERNEL_STRATEGY` to `cached`) or just leave it to the official kernel (set `KERNEL_STRATEGY` to `default` or leave it undefined). 
If `KERNEL_STRATEGY` is set to `build` but no `KERNEL_TAG` is defined then it defaults to the HEAD of the `rpi-6.12.y` branch. But please mind that some specific kernel patches (like GPIO Expander support) will not be applied since they are version-dependent.
The final step is to launch the build.sh script：

```bash
apt-get install coreutils quilt parted qemu-user-binfmt debootstrap zerofree zip \
dosfstools libarchive-tools libcap2-bin grep rsync xz-utils file git curl bc \
gpg pigz xxd arch-test
./build.sh -c config_rak
```

or, you can use docker to perform the build:

```bash
./build-docker.sh -c config_rak
```

Please check the original README.md to see how to skip stages and also how to continue the build after a failure.

## How the stage2-rak stage works

There are a number of different directories in the `stage2-rak` directory:

- **00-base** - Updates and installs new packages, new config.txt, sets up custom firstboot script
  
- **01-docker** - Installs docker, docker compose plugin, and adds user **rak** to docker group.
  
- **02-kernel** - Cross-builds a kernel that is tailored to the RAK7391.
  
- **03-utils** - Installs several scripts and utilities: boot AP, OLED script, rakpios-cli, MOTD, and so on.   

## Notice

- The default login credentials for the pre-built image are username: `rak` and password: `changeme`. Please note that it is important to change the default password upon first login to enhance security.
  
- In the case of WiFi-enabled CM4 modules and Raspberry Pi, the image will automatically create an access point when the device boots and no other connectivity options are enabled. This feature is based on [WiFi-connect](https://github.com/balena-os/wifi-connect) developed by Balena.
  
  This access point, named `RAK_XXXX` (where `XXXX` represents the last four digits of the `eth0` MAC address), enables users to configure an existing connection. The access point is secured with the password `rakwireless`. After connecting to the access point from a mobile phone or laptop, the captive portal will be detected and the web page will automatically open. In the event that the captive portal does not automatically redirect, please browse to `192.168.230.1` to access the captive portal.

- Portainer is no longer shipped as a standalone `portainer` script. It is now one of the services `rakpios-cli` can deploy, together with ChirpStack, Node-RED, Grafana, Mosquitto and others. To bring it up, run:

  ```bash
  rakpios-cli
  ```

  and pick *Deploy services* → *Portainer*. The same menu is used to stop and list running services.

## Branch management

The main development branch is "arm64". This holds the latest version of RAKPiOS. Stabel releases are tagged on the arm64 branch. 

The repository management strategy is as follows:

### Versioning

The major version tracks the Debian base: every image built on trixie is 1.x, and the first release on the next Debian version becomes 2.0.0. Minor and patch follow semantic versioning within a base.

Tying the major to the base is what keeps the semantic versioning claim honest. A new Debian release always brings changes we do not control and cannot call backwards compatible, so without that rule every upstream bump would either force a major or quietly break the promise.

### Upstream new releases

We create a new "release-xxx" branch based on rakpios/arm64 and merge remote changes:

```
git fetch upstream --tags
git tag -l '*trixie-arm64*' | sort
git checkout arm64
git checkout -b release-x.y.z
git merge 2025-12-04-raspios-trixie-arm64 --no-ff -m "Merge upstream tag '2025-12-04-raspios-trixie-arm64'"

# ... work ...

git checkout arm64
git merge --no-ff release-x.y.z
git tag -a YYYY-MM-DD-rakpios-x.y.z-trixie-arm64 -m "RAKPiOS vX.Y.Z"
git push github arm64
git push --tags
git branch -d release-x.y.z
```

### Feature Branches

```
git checkout arm64 && git pull github arm64
git checkout -b feature/<name>

# ... work ...

git push github feature/<name>
```

And Open PR → arm64
If arm64 moves forward during development:

```
git fetch github && git rebase github/arm64
```


### Fix Branches

```
git checkout -b fix/<description>

# ... fix ...

git push github fix/<description>
```

And open PR → arm64

