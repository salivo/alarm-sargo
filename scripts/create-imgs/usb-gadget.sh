#!/bin/bash

modprobe libcomposite
modprobe usb_f_ecm

mount -t configfs none /sys/kernel/config 2>/dev/null

cd /sys/kernel/config/usb_gadget/
mkdir -p g1
cd g1

echo 0x1d6b > idVendor  # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget
echo 0x0100 > bcdDevice
echo 0x0200 > bcdUSB

# String descriptors
mkdir -p strings/0x409
echo "1234567890" > strings/0x409/serialnumber
echo "Google" > strings/0x409/manufacturer
echo "Pixel 3a" > strings/0x409/product

# Create CDC Ethernet function
mkdir -p functions/ecm.usb0

# Create configuration
mkdir -p configs/c.1
mkdir -p configs/c.1/strings/0x409
echo "CDC Ethernet" > configs/c.1/strings/0x409/configuration

# Associate function with configuration
ln -s functions/ecm.usb0 configs/c.1/

echo "$(ls /sys/class/udc)" > UDC
