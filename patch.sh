#!/bin/sh

adb wait-for-device
adb -e push ramdisk.img.original /data/local/tmp/ramdisk.img.gz
adb -e push busybox-arm64-selinux /data/local/tmp/busybox
adb -e push magisk-arm64 /data/local/tmp/magisk-bin
adb -e push magiskboot-arm64 /data/local/tmp/magiskboot
adb -e push magiskinit-arm64 /data/local/tmp/magiskinit
adb -e push process.sh /data/local/tmp/
adb -e shell "dos2unix /data/local/tmp/process.sh"
adb -e shell "sh /data/local/tmp/process.sh /data/local/tmp $1"
adb -e pull /data/local/tmp/ramdisk.img ramdisk.img.patched
