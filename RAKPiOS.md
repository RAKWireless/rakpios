# RAKPiOS

This document describes the differences of RAKPiOS with Raspberry Pi OS.

## Introduction

This tool is used to create RAKPiOS images, a custom image based on Raspberry Pi OS, which was in turn derived from the Raspbian project.

The RAKPiOS image differs from the stock Raspberry Pi OS in:

* Overlays for existing components in RAK7391
* Docker installed by default, with live-restore and its major version held
* Automatic security updates, on by default, without automatic reboots
* Identifies as Debian 13 to vulnerability scanners, with the RAKPiOS version in its own fields
* A CycloneDX SBOM published with every release
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
VERSION=1.1.0
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
  
- **02-kernel** - With `KERNEL_STRATEGY=build` or `cached`, installs a kernel tailored to the RAK7391. With `default`, the image keeps Raspberry Pi's kernel.
  
- **03-utils** - Installs several scripts and utilities: boot AP, OLED script, rakpios-cli, MOTD, and so on.   

- **04-security** - Removes packages a gateway doesn't need, turns on automatic updates, enables Docker live-restore and holds Docker's major version. It checks the result and stops the build if anything is off.

The release tooling lives in `tools/`: `tools/sbom.sh` writes the SBOM of a finished image.

## Notice

- The default login credentials for the pre-built image are username: `rak` and password: `changeme`. Please note that it is important to change the default password upon first login to enhance security.
  
- In the case of WiFi-enabled CM4 modules and Raspberry Pi, the image will automatically create an access point when the device boots and no other connectivity options are enabled. This feature is based on [WiFi-connect](https://github.com/balena-os/wifi-connect) developed by Balena.
  
  This access point, named `RAK_XXXX` (where `XXXX` represents the last four digits of the `eth0` MAC address), enables users to configure an existing connection. The access point is secured with the password `rakwireless`. After connecting to the access point from a mobile phone or laptop, the captive portal will be detected and the web page will automatically open. In the event that the captive portal does not automatically redirect, please browse to `192.168.230.1` to access the captive portal.

- Portainer is no longer shipped as a standalone `portainer` script. It is now one of the services `rakpios-cli` can deploy, together with ChirpStack, Node-RED, Grafana, Mosquitto and others. To bring it up, run:

  ```bash
  rakpios-cli
  ```

  and pick *Deploy services* → *Portainer*. The same menu is used to stop and list running services.

## Security and updates

The reasons behind each of these choices, with what they cost, are in [docs/security-decisions.md](docs/security-decisions.md).

### Image identity

`/etc/os-release` describes the system as Debian 13, so vulnerability scanners apply Debian's security data to it. RAKPiOS fills the image fields:

```
PRETTY_NAME="RAKPiOS 1.1.0 (trixie)"
NAME="RAKPiOS"
VERSION="13 (trixie)"
VERSION_ID="13"
VERSION_CODENAME="trixie"
ID=debian
IMAGE_ID="rakpios"
IMAGE_VERSION="1.1.0"
COMMIT_SHA="…"
COMMIT_DATE="…"
```

`IMAGE_VERSION` is the RAKPiOS release, and `COMMIT_SHA` is the commit of this repository the image was built from. The MOTD and the OLED panel show the RAKPiOS version.

`base-files` owns this file and would replace it with Debian's on every upgrade, so RAKPiOS diverts it: `dpkg-divert --list /usr/lib/os-release` shows the diversion, and Debian's own file is kept at `/usr/lib/os-release.debian`.

### Automatic updates

Automatic updates are on by default. Once a day, Debian's `unattended-upgrades` installs updates from:

- Debian security updates (`trixie-security`) and Debian point releases (`trixie`);
- the Raspberry Pi archive, which carries the kernel, the firmware and Raspberry Pi's rebuilds of Debian packages;
- Docker CE, within the major version the image shipped with (see below).

The device never reboots by itself. An updated kernel, firmware or C library takes effect at the next reboot you choose. After a kernel update, `/var/run/reboot-required` exists until that reboot.

To turn automatic updates off, or back on:

```bash
sudo rakpios-auto-updates off
sudo rakpios-auto-updates on
rakpios-auto-updates status    # prints "on" or "off"
```

The same switch is in `rakpios-cli`, under *Automatic updates*. The setting survives upgrades of `unattended-upgrades`. With automatic updates off, update by hand with `sudo apt update && sudo apt full-upgrade`.

`apt` doesn't update the tools RAKPiOS installs outside it: the OLED panel, `rakpios-cli`, `mioty-cli` and the hardware test suite. `rakpios-cli --upgrade` updates `rakpios-cli`, and it tells you when a new version is out.

### Docker

`/etc/docker/daemon.json` enables live-restore: when Docker is upgraded, the daemon restarts without stopping the containers. This also means `sudo systemctl stop docker` no longer stops them; use `docker stop`.

Docker supports live-restore across patch releases (for example 29.10.0 to 29.10.1). Automatic updates also install new minor releases (29.10 to 29.11). If the new daemon can't reattach to a container after such an upgrade, the container keeps running but Docker can't manage it; stop it with `docker stop`, or reboot the device.

Docker and containerd are held to the major version the image shipped with, so automatic updates never move them to a new major. The hold is in `/etc/apt/preferences.d/docker-major-hold`. To move to a new major deliberately, change the version in that file, or delete the file, then run:

```bash
sudo apt update && sudo apt full-upgrade
```

### Removed packages

RAKPiOS removes packages from Raspberry Pi OS Lite that a gateway doesn't need: `rpicam-apps-lite`, `mkvtoolnix`, `rpi-connect-lite` and `docker-model-plugin`, along with the packages only they needed (the camera stack, Qt 6 core, libtiff and the mkvtoolnix libraries). To get any of them back, install it with `apt`, for example:

```bash
sudo apt install rpicam-apps-lite
```

### SBOM

Every release publishes a CycloneDX 1.6 SBOM of the image next to it (`<image>.cdx.json`, with a `.sha256`). It is made from the released image file by `tools/sbom.sh`, which catalogues it with Syft, validates it against the CycloneDX schema, and checks that it lists every installed package as a Debian package.

It covers the Debian and Raspberry Pi packages, the kernel modules, and the Go modules inside binaries such as Docker's. It doesn't cover RAKPiOS's own tools installed outside `apt` (the OLED panel, `rakpios-cli`, `mioty-cli`, the hardware test suite), which have no package metadata.

To make the SBOM of an image you built yourself:

```bash
tools/sbom.sh deploy/<image>.img.xz
```

## Branch management

The main development branch is "arm64". This holds the latest version of RAKPiOS. Stable releases are tagged on the arm64 branch. The branch is protected: changes reach it only through pull requests.

The repository management strategy is as follows:

### Versioning

The major version tracks the Debian base: every image built on trixie is 1.x, and the first release on the next Debian version becomes 2.0.0. Minor and patch follow semantic versioning within a base.

Tying the major to the base is what keeps the semantic versioning claim honest. A new Debian release always brings changes we do not control and cannot call backwards compatible, so without that rule every upstream bump would either force a major or quietly break the promise.

### Upstream new releases

We create a new "release-xxx" branch based on rakpios/arm64 and merge remote changes:

```
git fetch upstream --tags
git tag -l '*trixie-arm64*' | sort
git checkout arm64 && git pull github arm64
git checkout -b release-x.y.z
git merge 2025-12-04-raspios-trixie-arm64 --no-ff -m "Merge upstream tag '2025-12-04-raspios-trixie-arm64'"

# ... work ...
```

Build the release image from a committed tree: set `VERSION` in `config_rak` (and its copy above), commit, check that `git status --porcelain` prints nothing, then build and make the SBOM. The image records the commit it was built from in `COMMIT_SHA`, so uncommitted changes would ship in an image that no commit describes.

```
./build-docker.sh -c config_rak
tools/sbom.sh deploy/<image>.img.xz
git push github release-x.y.z
```

Open a pull request from `release-x.y.z` into `arm64` and merge it with **Create a merge commit**, never squash or rebase. A merge commit keeps the upstream tag in `arm64`'s history, so the next upstream merge doesn't reopen the conflicts this one resolved, and it keeps the commit the image names in `COMMIT_SHA`. Then tag the merge commit and push only that tag:

```
git checkout arm64 && git pull github arm64
git tag -a YYYY-MM-DD-rakpios-x.y.z-trixie-arm64 -m "RAKPiOS vX.Y.Z" <merge commit>
git push github YYYY-MM-DD-rakpios-x.y.z-trixie-arm64
git branch -d release-x.y.z && git push github --delete release-x.y.z
```

Create the GitHub release on that tag, with the image, the SBOM, their `.sha256` files and the release notes.

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

