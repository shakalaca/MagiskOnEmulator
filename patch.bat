@echo off

adb wait-for-device
adb -e push ramdisk.img /data/local/tmp/ramdisk.img.gz
adb -e push Magisk*.apk /data/local/tmp/magisk.zip
adb -e push busybox /data/local/tmp
adb -e push process.sh /data/local/tmp
adb -e shell "dos2unix /data/local/tmp/process.sh"
adb -e shell "sh /data/local/tmp/process.sh /data/local/tmp %1"
adb -e pull /data/local/tmp/ramdisk.img

