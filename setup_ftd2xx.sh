#!/bin/bash

if [[ "$OSTYPE" == "linux"* ]]; then
    FTD2XX=libftd2xx.so.1.4.8
    LNK=libftd2xx.so

    # It seems rule necessary for ftd2xx, dialout necessary for VCP
    echo "Enabling non-root access for RTBox"
    RULE_FILE=/etc/udev/rules.d/RTBox.rules
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", MODE="0666"' > $RULE_FILE
    usermod -aG dialout $USER

    echo "Disabling VCP driver"
    BL_FILE=/etc/modprobe.d/blacklist.conf
    echo '' >> $BL_FILE
    echo '# disable VCP driver to use ftd2xx driver' >> $BL_FILE
    echo 'blacklist ftdi_sio' >> $BL_FILE

elif [[ "$OSTYPE" == "darwin"* ]]; then
    FTD2XX=libftd2xx.1.4.16.dylib
    LNK=libftd2xx.dylib

else
    echo "Unknown OS: $OSTYPE"
    exit 1
fi

LIBDIR=/usr/local/lib
echo "Copying ftd2xx library to $LIBDIR"
mkdir -p $LIBDIR && cp ./lib/$FTD2XX $LIBDIR
chmod 0755 $LIBDIR/$FTD2XX
ln -sf $LIBDIR/$FTD2XX $LIBDIR/$LNK

echo "Please reboot to make change effect"
