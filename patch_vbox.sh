#!/bin/sh

# . patch.bat

adb wait-for-device
[[ -f magisk.zip ]] && adb -e push magisk.zip /data/local/tmp/magisk.zip
[[ -f magisk.apk ]] && adb -e push magisk.apk /data/local/tmp/magisk.zip
adb -e push busybox /data/local/tmp/
adb -e push process.sh /data/local/tmp/
adb -e push initrd.patch /data/local/tmp/
adb -e shell "dos2unix /data/local/tmp/process.sh"
adb -e shell "sh /data/local/tmp/process.sh /data/local/tmp $1"
