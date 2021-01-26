#!/system/bin/sh

if [ "$2" == "canary" ]; then
  USES_CANARY=1
fi
if [ "$2" == "manager" ]; then
  USES_MANAGER=1
fi
if [ "$2" == "canary_manager" ]; then
  USES_CANARY=1
  USES_MANAGER=1
fi
if [ "$2" == "pull" ]; then
  EXTRACT_RAMDISK=1
fi
BASE_DIR=$1
TMP_DIR=$BASE_DIR/tmp
MAGISK_DIR=$BASE_DIR/magisk
RAMDISK=$BASE_DIR/ramdisk.img
INITRD=$BASE_DIR/initrd.img

mkdir -p $TMP_DIR
mkdir -p $MAGISK_DIR

# prepare busybox
echo "[*] Extracting busybox .."
cd $BASE_DIR
sh update-binary -x > /dev/null 2>&1

BUSYBOX=$BASE_DIR/busybox

# platform check
echo "[*] Checking Android version"
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

if [[ -n $EXTRACT_RAMDISK ]]; then

echo "[*] Moving out patched boot.img .."
mv /sdcard/Download/magisk_patched*.img $TMP_DIR/boot.img

if [ -f $TMP_DIR/boot.img ]; then
  echo "[*] Extracting ramdisk .."
  rm -f ${RAMDISK}.gz
  dd if=$TMP_DIR/boot.img of=$RAMDISK bs=2048 skip=1
  $BUSYBOX gzip $RAMDISK
  mv ${RAMDISK}.gz $RAMDISK
else
  echo "[!] boot.img not found. "
fi

else 

# fetch latest magisk
if [[ -n $USES_CANARY ]]; then
  echo "[*] Fetching canary version of Magisk .."
  rm -f magisk.zip
  while [[ $STATUS != 0 ]]
  do
    $BUSYBOX wget -c https://raw.githubusercontent.com/topjohnwu/magisk_files/canary/app-debug.apk -O magisk.zip
    STATUS=$?
    if [[ $STATUS == 1 && -f magisk.zip ]] ; then
      F_SIZE=$(stat -c %s magisk.zip)
      BLOCK=$((F_SIZE/4096-2))
      echo "[*] Failed to get full magisk.zip, retry .. (" $BLOCK ")"
      dd if=magisk.zip of=magisk.zip.new bs=4096 count=$BLOCK > /dev/null 2>&1
      mv -f magisk.zip.new magisk.zip
    fi
  done  
fi
  
# extract and check ramdisk
$BUSYBOX gzip -fd ${RAMDISK}.gz

if [[ $API -ge 30 ]]; then
  echo "[-] API level greater then 30"
  echo "[*] Check if we need to repack ramdisk before patching .."
  COUNT=`$BUSYBOX strings -t d $RAMDISK | $BUSYBOX grep 00TRAILER\!\!\! | $BUSYBOX wc -l`  
  if [ $COUNT -gt 1 ]; then
    echo "[-] Multiple cpio archives detected"
    REPACK_RAMDISK=1
  fi
fi
  
if [[ -n $REPACK_RAMDISK ]]; then
  echo "[*] Unpacking ramdisk .."
  mkdir -p $TMP_DIR/ramdisk
  LAST_INDEX=0
  IBS=1
  OBS=4096

  RAMDISKS=`$BUSYBOX strings -t d $RAMDISK | $BUSYBOX grep 00TRAILER\!\!\!`
  for OFFSET in $RAMDISKS
  do
    # calculate offset to next archive
    if [[ $OFFSET == *"TRAILER"* ]]; then
      # find position of end of TRAILER!!! string in image
      LEN=${#OFFSET}
      START=$((LAST_INDEX+LEN))

      # find first occurance of string in image, that will be start of cpio archive
      dd if=$RAMDISK skip=$START count=$OBS ibs=$IBS obs=$OBS of=$TMP_DIR/temp.img > /dev/null 2>&1
      HEAD=(`$BUSYBOX strings -t d $TMP_DIR/temp.img | $BUSYBOX head -1`)
      
      # wola
      LAST_INDEX=$((START+HEAD[0]))
      continue
    fi

    # number of blocks we'll extract
    BLOCKS=$(((OFFSET+128)/IBS))
    
    # extract and dump
    echo "[-] Dumping from $LAST_INDEX to $BLOCKS .."
    dd if=$RAMDISK skip=$LAST_INDEX count=$BLOCKS ibs=$IBS obs=$OBS of=$TMP_DIR/temp.img > /dev/null 2>&1
    cd $TMP_DIR/ramdisk > /dev/null
      cat $TMP_DIR/temp.img | $BASE_DIR/busybox cpio -i > /dev/null 2>&1
    cd - > /dev/null
    LAST_INDEX=$OFFSET
  done

  echo "[*] Repacking ramdisk .."
  cd $TMP_DIR/ramdisk > /dev/null
    $BUSYBOX find . | $BUSYBOX cpio -H newc -o > $RAMDISK
  cd - > /dev/null

  rm $TMP_DIR/temp.img
fi

# extract files
echo "[*] Unzipping Magisk .."
$BUSYBOX unzip magisk.zip -od $TMP_DIR > /dev/null

COMMON=/common
if [[ -f $TMP_DIR/classes.dex ]]; then
  echo "[*] New Magisk packaging format detected .."
  [ "$ARCH" = "arm" ] && ARCH=armeabi-v7a
  USES_ZIP_IN_APK=1
  BINDIR=/lib
  COMMON=/assets
  cd ${TMP_DIR}${BINDIR}/$ARCH
  for libfile in lib*.so; do
    file="${libfile#lib}"; file="${file%.so}"
    mv "$libfile" "$file"
  done
  cd - > /dev/null
fi

mv ${TMP_DIR}${BINDIR}/$ARCH/* $MAGISK_DIR
mv ${TMP_DIR}${COMMON}/* $MAGISK_DIR
[ -d $TMP_DIR/chromeos ] && mv $TMP_DIR/chromeos $MAGISK_DIR
[ ! -f $MAGISK_DIR/busybox ] && cp $BUSYBOX $MAGISK_DIR

chmod 755 $MAGISK_DIR/*
if [[ -n $USES_ZIP_IN_APK ]]; then
  mv magisk.zip $MAGISK_DIR/magisk.apk
else
  $IS64BIT && mv -f $MAGISK_DIR/magiskinit64 $MAGISK_DIR/magiskinit || rm -f $MAGISK_DIR/magiskinit64
  $MAGISK_DIR/magiskinit -x magisk $MAGISK_DIR/magisk
fi

writehex() {
  printf "\x${1:6:2}\x${1:4:2}\x${1:2:2}\x${1:0:2}"
}

if [[ -n $USES_MANAGER ]]; then

echo "[*] Build fake boot.img .."

BOOT_IMG=/sdcard/boot.img
RAMDISK_SIZE="$(printf '%08x' $(stat -c%s $RAMDISK))"

rm -f $BOOT_IMG

printf "\x41\x4E\x44\x52\x4F\x49\x44\x21\x00\x00\x00\x00\x00\x80\x00\x10" >> $BOOT_IMG
writehex $RAMDISK_SIZE >> $BOOT_IMG
printf "\x00\x00\x00\x11\x00\x00\x00\x00\x00\x00\xF0\x10\x00\x01\x00\x10\x00\x08\x00\x00" >> $BOOT_IMG
i=0
while [[ $i -lt 251 ]];
do
  printf "\x00\x00\x00\x00\x00\x00\x00\x00" >> $BOOT_IMG
  i=$(($i+1))
done

cat $RAMDISK >> $BOOT_IMG

echo "[*] boot.img is ready, launch MagiskManager and patch it."

else

# check ramdisk status
echo "[*] Checking ramdisk status .."
$MAGISK_DIR/magiskboot cpio $RAMDISK test > /dev/null 2>&1
STATUS=$?
case $((STATUS & 3)) in
  0 )  # Stock boot
    echo "[-] Stock boot image detected"
    cp -af $RAMDISK ${RAMDISK}.orig
    ;;
  1 )  # Magisk patched
    echo "[-] Magisk patched boot image detected"
    $MAGISK_DIR/magiskboot cpio $RAMDISK restore > /dev/null 2>&1
    cp -af $RAMDISK ${RAMDISK}.orig
    ;;
  2 )  # Unsupported
    echo "[-] Boot image patched by unsupported programs"
    abort "! Please use stock ramdisk.img"
    ;;
esac

# patch ramdisk
echo "[*] Patching ramdisk .."
echo " "
echo "KEEPVERITY=false" >> config
echo "KEEPFORCEENCRYPT=true" >> config
if [[ -n $USES_ZIP_IN_APK ]]; then
  $MAGISK_DIR/magiskboot compress=xz $MAGISK_DIR/magisk32 $MAGISK_DIR/magisk32.xz
  $MAGISK_DIR/magiskboot compress=xz $MAGISK_DIR/magisk64 $MAGISK_DIR/magisk64.xz
  $IS64BIT && SKIP64="" || SKIP64="#"
  KEEPVERITY=false KEEPFORCEENCRYPT=true $MAGISK_DIR/magiskboot cpio $RAMDISK \
    "add 750 init $MAGISK_DIR/magiskinit" \
    "mkdir 0750 overlay.d" \
    "mkdir 0750 overlay.d/sbin" \
    "add 0644 overlay.d/sbin/magisk32.xz $MAGISK_DIR/magisk32.xz" \
    "$SKIP64 add 0644 overlay.d/sbin/magisk64.xz $MAGISK_DIR/magisk64.xz" \
    "patch" \
    "backup $RAMDISK.orig" \
    "mkdir 000 .backup" \
    "add 000 .backup/.magisk config"
else
  KEEPVERITY=false KEEPFORCEENCRYPT=true $MAGISK_DIR/magiskboot cpio $RAMDISK \
    "add 750 init $MAGISK_DIR/magiskinit" \
    "patch" \
    "backup ${RAMDISK}.orig" \
    "mkdir 000 .backup" \
    "add 000 .backup/.magisk config"
fi

# should be temporary hack
#if [[ $API -ge 30 ]]; then
#  $MAGISK_DIR/magiskboot cpio $RAMDISK "mkdir 755 apex"
#fi

echo "[*] Done patching, compressing ramdisk .."

fi # USES_MANAGER

$BUSYBOX gzip $RAMDISK
mv ${RAMDISK}.gz $RAMDISK

# install apk
echo "[*] Installing MagiskManager .."
pm install -r $MAGISK_DIR/magisk.apk > /dev/null
rm -f $MAGISK_DIR/magisk.apk

if [[ ! -n USES_MANAGER ]]; then

# move files
echo "[*] Installing su binaries .."
INSTALL_PATH=/data/user_de/0/com.topjohnwu.magisk/install/
if [[ $API -lt 24 ]]; then
  INSTALL_PATH=/data/data/com.topjohnwu.magisk/install/
fi
run-as com.topjohnwu.magisk mkdir $INSTALL_PATH > /dev/null 2>&1
run-as com.topjohnwu.magisk cp -r $MAGISK_DIR/* $INSTALL_PATH

fi # USES_MANAGER

# patch initrd
if [ -f ${INITRD}.gz ]; then
  $BUSYBOX gzip -fd ${INITRD}.gz
  mkdir i; cd i; cat $INITRD | $BUSYBOX cpio -i
  $BUSYBOX patch -p1 < ../initrd.patch
  $BUSYBOX find . | $BUSYBOX cpio -H newc -o | $BUSYBOX gzip > $INITRD
  cd ..; rm -rf i
fi

fi # EXTRACT_RAMDISK

# cleanup
echo "[*] Clean up"
rm -f config
rm -rf $TMP_DIR
rm -rf $MAGISK_DIR
rm -f busybox
rm -f update-binary
rm -f process.sh
rm -f magisk.zip
rm -f initrd.patch

