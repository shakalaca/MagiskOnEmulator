#!/bin/sh

adb wait-for-device
adb -e shell "mkdir /data/local/tmp/root"
adb -e shell "su -c 'mount /dev/block/sda1 /data/local/tmp/root'"
adb -e shell "cp /data/local/tmp/root/*/initrd.img /data/local/tmp/initrd.img.gz"
adb -e shell "cp /data/local/tmp/root/*/initrd.img.old /data/local/tmp/initrd.img.gz"
adb -e shell "cp /data/local/tmp/root/*/ramdisk.img /data/local/tmp/ramdisk.img.gz"
adb -e shell "cp /data/local/tmp/root/*/ramdisk.img.old /data/local/tmp/ramdisk.img.gz"
adb -e shell "su -c 'umount /data/local/tmp/root'"
adb -e shell "rmdir /data/local/tmp/root"
