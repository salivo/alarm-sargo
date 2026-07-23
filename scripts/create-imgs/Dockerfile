# syntax=docker/dockerfile:1.6
#
# Build a custom ArchLinux ARM (aarch64) rootfs and boot images with extra packages
# and the archpkg.salivon.eu repo added to pacman.
#
# Build (requires buildx + qemu binfmt for aarch64 emulation on non-ARM hosts):
#   docker run --privileged --rm tonistiigi/binfmt --install arm64
#   docker buildx build --platform linux/arm64 -o type=local,dest=./dist .


# Fetch base rootfs

FROM --platform=$BUILDPLATFORM alpine:3.20 AS fetcher

ARG ALARM_TARBALL_URL=http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

RUN apk add --no-cache curl tar xz \
    && mkdir -p /rootfs \
    && curl -fSL "${ALARM_TARBALL_URL}" -o /tmp/alarm.tar.gz \
    && tar -xpf /tmp/alarm.tar.gz -C /rootfs --numeric-owner \
    && rm -f /tmp/alarm.tar.gz

# Prepare rootfs 

FROM scratch AS rootfs

COPY --from=fetcher /rootfs/ /

RUN set -eux; \
    printf '[alarm-sargo]\nServer = https://archpkg.salivon.eu/aarch64\nSigLevel = Optional TrustAll\n\n' \
      | cat - /etc/pacman.conf > /tmp/pacman.conf.new; \
    mv /tmp/pacman.conf.new /etc/pacman.conf

RUN set -eux; \
    pacman-key --init; \
    pacman-key --populate archlinuxarm; \
    pacman -Rsn --noconfirm --disable-sandbox linux-aarch64; \
    pacman -Syyu --noconfirm --disable-sandbox

ARG PACKAGES="sargo-device-support"
ARG KERNEL_CMDLINE="earlycon=qcom_geni,0xa90000 root=/dev/mmcblk0p72 rw rootwait console=tty1 console=ttyHS0,115200n8 init=/lib/systemd/systemd"

RUN mkdir -p /etc/cmdline.d && \
    echo "${KERNEL_CMDLINE}" > /etc/cmdline.d/sargo.conf

RUN set -eux; \
    pacman -Sy --noconfirm --disable-sandbox --needed ${PACKAGES}; \
    pacman -Scc --noconfirm; \
    rm -rf /var/cache/pacman/pkg/* /var/log/* /tmp/* /var/tmp/*

# Enable USB Gadget mode and sshd

COPY usb-gadget.sh /usr/local/bin/
COPY usb-gadget.service /etc/systemd/system/
COPY 80-usb0.network /etc/systemd/network/

RUN systemctl enable sshd.service
RUN systemctl enable usb-gadget.service

# Pack it all 

FROM --platform=$BUILDPLATFORM alpine:3.20 AS packer
 
RUN apk add --no-cache e2fsprogs
 
COPY --from=rootfs / /rootfs-src
 
ARG IMG_LABEL=ALARM_ROOT
ARG IMG_EXTRA_MB=512
ARG BOOT_IMG_PATH=boot/boot-sargo.img

RUN set -eux; \
    mkdir -p /out; \
    test -f "/rootfs-src/${BOOT_IMG_PATH}"; \
    cp "/rootfs-src/${BOOT_IMG_PATH}" "/out/$(basename "${BOOT_IMG_PATH}")"; \
    SIZE_MB=$(( $(du -sm /rootfs-src | cut -f1) + IMG_EXTRA_MB )); \
    mke2fs -t ext4 -L "${IMG_LABEL}" -d /rootfs-src /out/rootfs.img "${SIZE_MB}M"

FROM scratch
COPY --from=packer /out/ /
