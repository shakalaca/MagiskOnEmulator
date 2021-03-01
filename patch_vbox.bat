@echo off

adb wait-for-device
adb -e push magisk.zip "/data/local/tmp/"
adb -e push busybox "/data/local/tmp/"
adb -e push process.sh "/data/local/tmp/"
adb -e push initrd.patch "/data/local/tmp/"
adb -e shell "dos2unix /data/local/tmp/process.sh"
adb -e shell "sh /data/local/tmp/process.sh /data/local/tmp %1"
