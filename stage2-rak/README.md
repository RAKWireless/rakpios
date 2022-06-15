# Notes about RAKPiOS specific features

Changes to the default Raspberry Pi OS image are defined on the `stage2-rak` stage. This is used to build a customized image for RAK WisGate Developer products. The stage will make some changes to the systems, including pre-installing docker and other tools, adding new kernel modules, updating system information, and adding some new features tailored for RAK WisGate Developer products. 


## Getting started with building using stage2-rak

As mentioned in the original `README.md`, users can define a variable called  `STAGE_LIST` in the configuration file to change the order of building stages. In the `default_config` file, variable `STAGE_LIST` is set to `stage0 stage1 stage2 stage2-rak`, then instead of working through the numeric stages in order, this list will be followed. 

RAKPiOS is a *lite* system, thus the build will skip stage 3, stage 4, and stage 5 which are only for a desktop system with a graphical user interface.  


## A simple example for building RakpiOS image

We defined some original configuration tags and also introduced some custom configuration tags in the `config_rak` file. 

```
# Original configuration tags
ARCH=arm64
VERSION=0.3.4
IMG_NAME="rakpios-${VERSION}-${ARCH}"
TARGET_HOSTNAME="rakpios"
FIRST_USER_NAME="rak"
FIRST_USER_PASS="rakpios"
ENABLE_SSH=1
STAGE_LIST="stage0 stage1 stage2 stage2-rak"
IMG_DATE=$( date +%Y%m%d )

# Custom configuration tags
PI_GEN_REPO=https://github.com/RAKWireless/rakpios
KERNEL_BUILD=0
KERNEL_CACHED=1
KERNEL_TAG=ac66b3f
```

For more details about the original configurations, please check the original `READMD.md` . For custom configuration tags, now you can define whether you want to build the kernel (`KERNEL_BUILD` and `KERNEL_TAG` variables), use the cached image (`KERNEL_CACHED` variable) or just leave it to the official kernel. 

If `KERNEL_BUILD` is set to 1 but no `KERNEL_TAG` is defined then it defaults to the HEAD of the `rpi-5.15.y` branch. But please mind that some specific kernel patches (like GPIO Expander support) will not be applied since they are version-dependent.

The final step is to launch the build.sh script：

```bash
sudo ./build.sh -c config_rak
```

or, you can use docker to perform the build:

```
./build-docker.sh -c config_rak
```

Please check the original README.md to see how to skip stages and also how to continue the build after a failure.


## How the stage2-rak stage works

There are a number of different directories in the `stage2-rak` directory:

  - **00-configure-apt** -Update `sources.list.d` and pre-install docker's dependencies.

  - **01-pre-installt.sh** - Pre-install docker, docker-compose, python libraries, and add user **rak** user to docker group. 
    
  - **02-kernel** - A kernel builder allows you to cross-build a kernel that is tailored exactly to your requirements.
    
  - **03-sys-update** - This stage focused on moving script to the new image, adding new features like rakuid,  OLED script, portainer, MOTD, and so on. This stage also update the new image's os-releases file.
    

