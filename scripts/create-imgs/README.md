# create-imgs

This directory contains the necessary Dockerfile and scripts to build a custom ArchLinux ARM (aarch64) rootfs and boot image for the "sargo" device (Pixel 3a).

## Prerequisites

Building the images requires Docker with `buildx` support and `qemu-user-static` (binfmt) for aarch64 emulation if you are building on a non-ARM host.

Install the aarch64 binfmt emulator:
```sh
docker run --privileged --rm tonistiigi/binfmt --install arm64
```

## How to Build

Run the following command in this directory to build the images. The output will be placed in the `dist` folder.
```sh
docker buildx build --platform linux/arm64 -o type=local,dest=./dist .
```

This process will download the base ArchLinux ARM rootfs, configure it, install necessary packages (like `sargo-device-support`), and finally output the `boot-sargo.img` and `rootfs.img` files to `./dist`.

## How to Flash All

Once the images are built in the `dist` directory, you can flash them to your device. Ensure your device is in `fastboot` mode and connected to your computer.

Run the following `fastboot` commands to flash all the required images:

```sh
fastboot flash boot dist/boot-sargo.img
fastboot flash userdata dist/rootfs.img
fastboot reboot
```
