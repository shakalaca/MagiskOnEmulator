#!/bin/sh

adb wait-for-device
adb -e push install.sh /data/local/tmp
adb -e shell "su -c 'sh /data/local/tmp/install.sh /data/local/tmp'"
