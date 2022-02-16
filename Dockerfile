ARG BASE_IMAGE=debian:bullseye
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        # utils
        build-essential binfmt-support ca-certificates fdisk vim libffi-dev \
        # pi-gen (based on `depends` file)
        quilt parted coreutils qemu-user-static debootstrap zerofree zip dosfstools libcap2-bin libarchive-tools grep rsync udev xz-utils curl xxd file git kmod bc qemu-utils kpartx gpg \
        # kernel (unzip cached files or build it)
        unzip bison flex libssl-dev libc6-dev libncurses5-dev crossbuild-essential-armhf crossbuild-essential-arm64 \
    && rm -rf /var/lib/apt/lists/*

VOLUME [ "/pi-gen/work", "/pi-gen/deploy"]
