@echo off

adb wait-for-device;
adb -e push magisk.zip "/data/local/tmp/";
adb -e push update-binary "/data/local/tmp/";
adb -e push process.sh "/data/local/tmp/";
adb -e push initrd.patch "/data/local/tmp/";
adb -e shell "sh /data/local/tmp/process.sh /data/local/tmp";
