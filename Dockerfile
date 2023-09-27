ARG BASE_IMAGE=debian:bullseye
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && \
    apt-get -y install --no-install-recommends \
        # pi-gen (based on upstream Dockerfile)
        git vim parted \
        quilt coreutils qemu-user-static debootstrap zerofree zip dosfstools \
        libarchive-tools libcap2-bin rsync grep udev xz-utils curl xxd file kmod bc\
        binfmt-support ca-certificates qemu-utils kpartx fdisk gpg pigz\
        # kernel (unzip cached files or build it)
        jq build-essential libffi-dev unzip bison flex libssl-dev libc6-dev libncurses5-dev crossbuild-essential-armhf crossbuild-essential-arm64 \
        # preprovision docker images
        docker.io \
    && rm -rf /var/lib/apt/lists/*

COPY . /pi-gen/

VOLUME [ "/pi-gen/work", "/pi-gen/deploy"]
