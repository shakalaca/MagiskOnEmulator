#!/usr/bin/env bash

magiskFile=$(ls -1 Magisk*{.zip,.apk} | head -n1)

if [[ -z $magiskFile ]]; then
  echo "No Magisk*.zip or Magisk*.apk file found. Please download and rename it first!"
  exit 1
fi

ramdiskFile=ramdisk.img

if [[ ! -f $ramdiskFile ]]; then
  echo "No ramdisk.img found! Copy it to this directory first."
  exit 1
fi

echo "Waiting for device ..."
adb wait-for-device

echo "Pushing data ..."
adb -e push "$magiskFile" /data/local/tmp/magisk.zip
adb -e push "$ramdiskFile" /data/local/tmp/ramdisk.img.gz
adb -e push busybox /data/local/tmp/
adb -e push process.sh /data/local/tmp/

echo "Processing"
adb -e shell "dos2unix /data/local/tmp/process.sh"
adb -e shell "sh /data/local/tmp/process.sh /data/local/tmp $1"

echo "Pulling ramdisk"
adb -e pull /data/local/tmp/ramdisk.img

echo "Done. Copy ramdisk.img back to the SDK location!"
