#!/system/bin/sh

MNT_ROOT=/data/local/tmp/root
BASE_DIR=$1

mkdir $MNT_ROOT
mount /dev/block/sda1 $MNT_ROOT

INITRD=`ls $MNT_ROOT/*/initrd.img`
RAMDSK=`ls $MNT_ROOT/*/ramdisk.img`

if [ ! -f ${INITRD}.old ]; then
  cp $INITRD ${INITRD}.old
fi
if [ -f ${INITRD}.old ]; then
  cp $BASE_DIR/initrd.img $INITRD
fi

if [ ! -f ${RAMDSK}.old ]; then
  cp $RAMDSK ${RAMDSK}.old
fi
if [ -f ${RAMDSK}.old ]; then
  cp $BASE_DIR/ramdisk.img $RAMDSK
fi

sync; sync

umount $MNT_ROOT
rmdir $MNT_ROOT
rm -f $BASE_DIR/install.sh
