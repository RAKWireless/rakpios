ARG BASE_IMAGE=debian:bullseye
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        # pi-gen (based on upstream Dockerfile)
        git vim parted \
        quilt coreutils qemu-user-binfmt debootstrap zerofree zip dosfstools e2fsprogs qemu-utils kpartx \
        libarchive-tools libcap2-bin rsync grep udev xz-utils curl xxd file kmod bc \
        binfmt-support ca-certificates fdisk gpg pigz arch-test device-tree-compiler \
        # kernel (unzip cached files or build it)
        jq build-essential libffi-dev unzip bison flex libssl-dev libc6-dev libncurses5-dev crossbuild-essential-armhf crossbuild-essential-arm64 \
    && rm -rf /var/lib/apt/lists/*

COPY . /pi-gen/

VOLUME [ "/pi-gen/work", "/pi-gen/deploy"]
