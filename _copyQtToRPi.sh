#!/bin/bash

if [ "$#" -ne 2 ]; then
	echo "Parameter count does not match."
	exit -1
fi

# RPI_USERNAME=$1
# RPI_IP_ADDR=$2

rsync -avz --rsync-path="sudo rsync" qt-raspi/* ${PI_USERNAME}@${WOMBAT_IP_ADDRESS}:/usr/local/qt6

echo "Done copying files to Raspberry Pi."