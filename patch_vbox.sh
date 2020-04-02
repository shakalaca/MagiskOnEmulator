#!/bin/sh

# . patch.bat

adb wait-for-device
adb -e push ramdisk.img /data/local/tmp/ramdisk.img.gz
adb -e push magisk.zip /data/local/tmp/
adb -e push update-binary data/local/tmp/
adb -e push process.sh /data/local/tmp/
adb -e push initrd.patch /data/local/tmp/
adb -e push initrd.img /data/local/tmp/initrd.img.gz
adb -e shell "sh /data/local/tmp/process.sh /data/local/tmp"
