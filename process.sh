#!/system/bin/sh

if [ "$2" == "canary" ]; then
  USES_CANARY=1
fi
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

# fetch latest magisk
if [[ -n $USES_CANARY ]]; then
  rm -f magisk.zip
  $BUSYBOX wget -c https://raw.githubusercontent.com/topjohnwu/magisk_files/canary/magisk-debug.zip -O magisk.zip
fi
  
# extract and check ramdisk
$BUSYBOX gzip -fd ${RAMDISK}.gz

if [[ $API -ge 30 ]]; then
  COUNT=`$BUSYBOX strings -t d $RAMDISK | $BUSYBOX grep 00TRAILER\!\!\! | $BUSYBOX wc -l`  
  if [ $COUNT -gt 1 ]; then
    REPACK_RAMDISK=1
  fi
fi
  
if [[ -n $REPACK_RAMDISK ]]; then
  mkdir -p $TMP_DIR/ramdisk
  LAST_INDEX=0
  BS=4096

  RAMDISKS=`$BUSYBOX strings -t d $RAMDISK | $BUSYBOX grep 00TRAILER\!\!\!`
  for OFFSET in $RAMDISKS
  do
    # skip content
    if [[ $OFFSET == *"TRAILER"* ]]; then
      continue
    fi

    # number of blocks we'll extract
    BLOCKS=$((OFFSET/BS+1-LAST_INDEX))
    
    # plus 1 if the real bytes are too close
    if [[ $((BLOCKS*BS-OFFSET)) < $((BS/2)) ]]; then
      BLOCKS=$((BLOCKS+1))
    fi
    
    # extract and dump
    dd if=$RAMDISK skip=$LAST_INDEX count=$BLOCKS bs=$BS of=$TMP_DIR/temp.img
    cd $TMP_DIR/ramdisk
      cat $TMP_DIR/temp.img | $BASE_DIR/busybox cpio -i
    cd -
    LAST_INDEX=$BLOCKS   
  done

  cd $TMP_DIR/ramdisk
    $BUSYBOX find . | $BUSYBOX cpio -H newc -o > $RAMDISK
  cd -

  rm $TMP_DIR/temp.img
fi

# extract files
$BUSYBOX unzip magisk.zip -d $TMP_DIR

mv $TMP_DIR/$ARCH/* $MAGISK_DIR
mv $TMP_DIR/common/* $MAGISK_DIR
mv $TMP_DIR/chromeos $MAGISK_DIR
cp $BUSYBOX $MAGISK_DIR
$IS64BIT && mv -f $MAGISK_DIR/magiskinit64 $MAGISK_DIR/magiskinit || rm -f $MAGISK_DIR/magiskinit64

chmod 755 $MAGISK_DIR/*
$MAGISK_DIR/magiskinit -x magisk $MAGISK_DIR/magisk

# check ramdisk status
echo "[*] Checking ramdisk status .."
$MAGISK_DIR/magiskboot cpio $RAMDISK test > /dev/null 2>&1
STATUS=$?
case $((STATUS & 3)) in
  0 )  # Stock boot
    echo "[-] Stock boot image detected"
    ;;
  1 )  # Magisk patched
    echo "[-] Magisk patched boot image detected"
    $MAGISK_DIR/magiskboot cpio $RAMDISK restore > /dev/null 2>&1
    ;;
  2 )  # Unsupported
    echo "[-] Boot image patched by unsupported programs"
    abort "! Please use stock ramdisk.img"
    ;;
esac

# patch ramdisk
echo "KEEPVERITY=false" >> config
echo "KEEPFORCEENCRYPT=true" >> config
$MAGISK_DIR/magiskboot cpio $RAMDISK "mkdir 000 .backup" "mv init .backup/init" 
# should be temporary hack
if [[ $API -ge 30 ]]; then
  $MAGISK_DIR/magiskboot cpio $RAMDISK "mkdir 755 apex"
fi
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

