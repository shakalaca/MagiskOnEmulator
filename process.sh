#!/system/bin/sh

TMP_DIR=/data/local/tmp/tmp
MAGISK_DIR=/data/local/tmp/magisk

# setup environment
cd /data/local/tmp
mkdir $TMP_DIR
mkdir $MAGISK_DIR
chmod 755 busybox
./busybox gzip -fd ramdisk.img.gz
mv ramdisk.img $MAGISK_DIR

# extract files
./busybox unzip magisk.zip -d $TMP_DIR

pm install -r $TMP_DIR/common/magisk.apk
rm $TMP_DIR/common/magisk.apk

mv $TMP_DIR/x86/* $MAGISK_DIR
mv $TMP_DIR/common/* $MAGISK_DIR
mv $TMP_DIR/chromeos $MAGISK_DIR
mv $TMP_DIR/META-INF/com/google/android/update-binary $MAGISK_DIR

cd $MAGISK_DIR
chmod 755 *
sh update-binary -x

# extract magisk
./magiskinit -x magisk magisk

# install magiskinit
echo "KEEPVERITY=false" >> config
echo "KEEPFORCEENCRYPT=true" >> config
./magiskboot cpio ramdisk.img "mkdir 000 .backup" "mv init .backup/init" 
./magiskboot cpio ramdisk.img "add 750 init magiskinit" "add 000 .backup/.magisk config"
KEEPVERITY=false KEEPFORCEENCRYPT=true ./magiskboot cpio ramdisk.img patch
gzip ramdisk.img
mv ramdisk.img.gz /data/local/tmp/ramdisk.img

# clean up
rm -f config
rm -f update-binary

# move files
run-as com.topjohnwu.magisk cp -a $MAGISK_DIR /data/user_de/0/com.topjohnwu.magisk/install

rm -rf $TMP_DIR
rm -rf $MAGISK_DIR
