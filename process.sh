#!/system/bin/sh

BASE_DIR=$1
TMP_DIR=$BASE_DIR/tmp
MAGISK_DIR=$BASE_DIR/magisk
RAMDISK=$BASE_DIR/ramdisk.img
INITRD=$BASE_DIR/initrd.img

mkdir -p $TMP_DIR
mkdir -p $MAGISK_DIR

# prepare busybox
cd $BASE_DIR
sh update-binary -x

BUSYBOX=$BASE_DIR/busybox

# platform check
API=`getprop ro.build.version.sdk`
ABI=`getprop ro.product.cpu.abi | $BUSYBOX cut -c-3`
ABI2=`getprop ro.product.cpu.abi2 | $BUSYBOX cut -c-3`
ABILONG=`getprop ro.product.cpu.abi`

ARCH=arm
IS64BIT=false
if [ "$ABI" = "x86" ]; then ARCH=x86; fi;
if [ "$ABI2" = "x86" ]; then ARCH=x86; fi;
if [ "$ABILONG" = "arm64-v8a" ]; then ARCH=arm; IS64BIT=true; fi;
if [ "$ABILONG" = "x86_64" ]; then ARCH=x86; IS64BIT=true; fi;
  
# extract files
$BUSYBOX gzip -fd ${RAMDISK}.gz
$BUSYBOX unzip magisk.zip -d $TMP_DIR

mv $TMP_DIR/$ARCH/* $MAGISK_DIR
mv $TMP_DIR/common/* $MAGISK_DIR
mv $TMP_DIR/chromeos $MAGISK_DIR
cp $BUSYBOX $MAGISK_DIR
$IS64BIT && mv -f $MAGISK_DIR/magiskinit64 $MAGISK_DIR/magiskinit || rm -f $MAGISK_DIR/magiskinit64

chmod 755 $MAGISK_DIR/*
$MAGISK_DIR/magiskinit -x magisk $MAGISK_DIR/magisk

# patch ramdisk
echo "KEEPVERITY=false" >> config
echo "KEEPFORCEENCRYPT=true" >> config
$MAGISK_DIR/magiskboot cpio $RAMDISK "mkdir 000 .backup" "mv init .backup/init" 
$MAGISK_DIR/magiskboot cpio $RAMDISK "add 750 init $MAGISK_DIR/magiskinit" "add 000 .backup/.magisk config"
KEEPVERITY=false KEEPFORCEENCRYPT=true $MAGISK_DIR/magiskboot cpio $RAMDISK patch
$BUSYBOX gzip $RAMDISK
mv ${RAMDISK}.gz $RAMDISK

# install apk
pm install -r $MAGISK_DIR/magisk.apk
rm -f $MAGISK_DIR/magisk.apk

# move files
INSTALL_PATH=/data/user_de/0/com.topjohnwu.magisk/install/
if [[ $API -lt 24 ]]; then
  INSTALL_PATH=/data/data/com.topjohnwu.magisk/install/
fi
run-as com.topjohnwu.magisk mkdir $INSTALL_PATH
run-as com.topjohnwu.magisk cp -r $MAGISK_DIR/* $INSTALL_PATH

# patch initrd
if [ -f ${INITRD}.gz ]; then
  $BUSYBOX gzip -fd ${INITRD}.gz
  mkdir i; cd i; cat $INITRD | $BUSYBOX cpio -i
  $BUSYBOX patch -p1 < ../initrd.patch
  $BUSYBOX find . | $BUSYBOX cpio -H newc -o | $BUSYBOX gzip > $INITRD
  cd ..; rm -rf i
fi

# cleanup
rm -f config
rm -rf $TMP_DIR
rm -rf $MAGISK_DIR
rm -f busybox
rm -f update-binary
rm -f process.sh
rm -f magisk.zip
rm -f initrd.patch

