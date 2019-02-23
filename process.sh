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
#ln -s ./magiskinit magiskpolicy
chmod 755 *
sh update-binary -x

# extract magisk
./magiskinit -x magisk magisk

if [ -f /vendor/etc/selinux/precompiled_sepolicy ]; then
  # extract init and patch
  ./magiskboot --cpio ramdisk.img "extract init init"
  ./magiskboot --hexpatch init \
  2F73797374656D2F6574632F73656C696E75782F706C61745F7365706F6C6963792E63696C \
  2F73797374656D2F6574632F73656C696E75782F706C61745F7365706F6C6963792E585858
  ./magiskboot --cpio ramdisk.img "rm init" "add 750 init init"

  # add sepolicy
  #./magiskpolicy --load /vendor/etc/selinux/precompiled_sepolicy --magisk --save sepolicy
  cp /vendor/etc/selinux/precompiled_sepolicy sepolicy
  ./magiskboot --cpio ramdisk.img "add 750 sepolicy sepolicy"
fi

# install magiskinit
echo "KEEPVERITY=true" >> config
echo "KEEPFORCEENCRYPT=true" >> config
./magiskboot --cpio ramdisk.img "mkdir 000 .backup" "mv init .backup/init" "add 750 init magiskinit" "add 000 .backup/.magisk config"
gzip ramdisk.img
mv ramdisk.img.gz /data/local/tmp/ramdisk.img

# clean up
rm -f config
rm -f update-binary
rm -f init
#rm -f magiskpolicy
rm -f sepolicy

# move files
run-as com.topjohnwu.magisk mkdir install
run-as com.topjohnwu.magisk cp -r $MAGISK_DIR/* ./install

rm -rf $TMP_DIR
rm -rf $MAGISK_DIR
