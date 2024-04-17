#!/bin/bash

# Raspberry Pi details
PI_USERNAME="kipr"
PI_HOST="$WOMBAT_IP_ADDRESS"
PI_DESTINATION="/home/kipr"

# Source file on Docker container
LIBKAR_FILE="/home/qtpi/libkar/build/libkar-0.1.1-Linux.deb"
PCOMPILER_FILE="/home/qtpi/pcompiler/build/pcompiler-0.1.1-Linux.deb"
KIPR_FILE="/home/qtpi/libwallaby/build/kipr-1.0.0-Linux.deb"
BOTUI_FILE="/home/qtpi/botui/build/botui-0.1.1-Linux.deb"
# SCP command
scppass() {
    sshpass -p "$1" scp -r -o StrictHostKeyChecking=no "$2" "$3@$4:$5"
}

# Copy file to Raspberry Pi
scppass "$PI_PASSWORD" "$LIBKAR_FILE" "$PI_USERNAME" "$PI_HOST" "$PI_DESTINATION"
scppass "$PI_PASSWORD" "$PCOMPILER_FILE" "$PI_USERNAME" "$PI_HOST" "$PI_DESTINATION"
scppass "$PI_PASSWORD" "$KIPR_FILE" "$PI_USERNAME" "$PI_HOST" "$PI_DESTINATION"
scppass "$PI_PASSWORD" "$BOTUI_FILE" "$PI_USERNAME" "$PI_HOST" "$PI_DESTINATION"


_copyQtToRPi.sh kipr $WOMBAT_IP_ADDRESS