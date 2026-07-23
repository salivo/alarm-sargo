#!/bin/bash
# /usr/bin/set-sargo-bt-mac.sh

MAC_FILE="/etc/bluetooth/sargo-bt-mac"

if [ ! -f "$MAC_FILE" ]; then
    mkdir -p /etc/bluetooth
    
    SERIAL=$(grep -o 'androidboot.serialno=[^ ]*' /proc/cmdline | cut -d= -f2)
    
    if [ -n "$SERIAL" ]; then
        # Hash the serial and format it. 
        # The '02:' prefix sets the "Locally Administered" bit, making it a valid custom MAC.
        SUFFIX=$(echo -n "$SERIAL" | md5sum | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\).*/\1:\2:\3:\4:\5/')
        MAC="02:$SUFFIX"
    else
        # Fallback to a completely random MAC if serial is missing
        MAC=$(printf '02:%02X:%02X:%02X:%02X:%02X\n' $[RANDOM%256] $[RANDOM%256] $[RANDOM%256] $[RANDOM%256] $[RANDOM%256])
    fi
    
    echo "$MAC" > "$MAC_FILE"
fi

MAC=$(cat "$MAC_FILE")

btmgmt -i hci0 public-addr "$MAC"
