#!/system/bin/sh

if [ "$2" == "canary" ]; then
  USES_CANARY=1
fi
if [ "$2" == "pull" ]; then
  EXTRACT_RAMDISK=1
fi

BASE_DIR=$1
TMP_DIR=$BASE_DIR/tmp
MAGISK_DIR=$BASE_DIR/magisk
RAMDISK=$BASE_DIR/ramdisk.img
BUSYBOX=$BASE_DIR/busybox

mkdir -p $TMP_DIR
mkdir -p $MAGISK_DIR

cleanup() {
  # cleanup
  echo "[*] Clean up"
  rm -f config
  rm -rf $TMP_DIR
  rm -rf $MAGISK_DIR
  rm -f busybox
  rm -f process.sh
  rm -f magisk.zip
}

writehex() {
  printf "\x${1:6:2}\x${1:4:2}\x${1:2:2}\x${1:0:2}"
}

# ========================================================================== #

# prepare busybox
cd $BASE_DIR
chmod 755 $BUSYBOX

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

  cleanup
  exit 0
fi # EXTRACT_RAMDISK

# fetch latest magisk
if [[ -n $USES_CANARY ]]; then
  echo "[*] Fetching canary version of Magisk .."
  rm -f magisk.zip
  $BUSYBOX wget -c https://raw.githubusercontent.com/topjohnwu/magisk-files/canary/app-debug.apk -O magisk.apk
fi

# extract files
echo "[*] Prepare Magisk Binary: busybox, magisk, magiskboot, magiskinit"

cp ${BASE_DIR}/busybox $MAGISK_DIR
mv ${BASE_DIR}/magisk-bin $MAGISK_DIR/magisk
mv ${BASE_DIR}/magiskboot $MAGISK_DIR
mv ${BASE_DIR}/magiskinit $MAGISK_DIR

echo "Post moving"

chmod 755 $MAGISK_DIR/*
echo "Pre magiskinit-ing"
$MAGISK_DIR/magiskinit -x magisk $MAGISK_DIR/magisk
echo "Post magiskinit-ing"

# extract and check ramdisk
$BUSYBOX gzip -fd ${RAMDISK}.gz
if [[ $? -ne 0 ]]; then
  echo "[-] Failed to unzip ramdisk, just use it .."
  mv ${RAMDISK}.gz ${RAMDISK}
  TRY_LZ4=1
fi

if [[ $API -ge 30 ]]; then
  echo "[-] API level greater then 30"
  echo "[*] Check if we need to repack ramdisk before patching .."
  COUNT=`$BUSYBOX strings -t d $RAMDISK | $BUSYBOX grep TRAILER\!\!\! | $BUSYBOX wc -l`  
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

  RAMDISKS=`$BUSYBOX strings -t d $RAMDISK | $BUSYBOX grep TRAILER\!\!\!`
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
      [[ -n $TRY_LZ4 ]] && MAGIC=9 || MAGIC=$((HEAD[0]))
      LAST_INDEX=$((START+MAGIC))
      continue
    fi

    # number of blocks we'll extract
    BLOCKS=$(((OFFSET+128)/IBS))
    
    # extract and dump
    echo "[-] Dumping from $LAST_INDEX to $BLOCKS .."
    dd if=$RAMDISK skip=$LAST_INDEX count=$BLOCKS ibs=$IBS obs=$OBS of=$TMP_DIR/temp.img > /dev/null 2>&1
    cd $TMP_DIR/ramdisk > /dev/null
      if [[ -n $TRY_LZ4 ]]; then
        $MAGISK_DIR/magiskboot decompress $TMP_DIR/temp.img $TMP_DIR/temp_decompress.img
        if [[ $? -eq 0 ]]; then
          mv $TMP_DIR/temp_decompress.img $TMP_DIR/temp.img
        fi
      fi
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

if [[ ! -n $USES_MANAGER ]]; then
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
pm install -r $BASE_DIR/magisk.apk > /dev/null
rm -f $BASE_DIR/magisk.apk

# grant permission for modules
if [[ $API -lt 30 ]]; then
  pm grant com.topjohnwu.magisk android.permission.WRITE_EXTERNAL_STORAGE
fi

# check if emulator has root
SU_CHK=$(id)
if [[ $SU_CHK == "uid=0"* ]]; then
  HAS_ROOT=1
  SU="eval"
else
  SU='/system/xbin/su -c'
  SU_CHK=`/system/xbin/su -c id`
  if [[ $SU_CHK == "uid=0"* ]]; then
    HAS_ROOT=1
  else
    SU='/system/xbin/su 0 sh -c'
    SU_CHK=`/system/xbin/su 0 id`
    if [[ $SU_CHK == "uid=0"* ]]; then
      HAS_ROOT=1
    fi
  fi
fi

# query installed app path
RET=$(pm path com.topjohnwu.magisk)

# remove 'package:'
FILTER_PACKAGE=${RET##*:}

# remove '/base.apk'
APP_PATH=${FILTER_PACKAGE%/*}/lib/x86

if [[ -n $USES_ZIP_IN_APK ]] && [[ $ARCH == "x86" ]] && [[ ! -d $APP_PATH ]] ; then
  echo "[*] Try to fix missing x86 libraries .. "

  if [[ -n $HAS_ROOT ]]; then
    echo "[-] Preparing directory .. "
    $SU "mkdir -p $APP_PATH"

    # copy to lib/x86/lib*.so
    for p in ${TMP_DIR}${BINDIR}/x86/* ; do
      BIN=${p##*/}
      echo "[-] copying" $p
      $SU "cp ${p} $APP_PATH/lib${BIN}.so"
    done

    # set owner and permissions
    $SU "chown -R system:system $APP_PATH"
    $SU "chmod -R 755 $APP_PATH"
    $SU "rm -rf ${APP_PATH%/*}/arm"
    if [[ -d ${APP_PATH%/*}/x86_64 ]]; then
      $SU "rm -rf ${APP_PATH%/*}/x86_64"
      $SU "mv $APP_PATH ${APP_PATH%/*}/x86_64"
    fi
  else
    echo "[-] We need root to do this .. :( "
  fi
fi

if [[ ! -n $USES_MANAGER ]]; then
  # move files
  echo "[*] Installing su binaries .."
  INSTALL_PATH=/data/user_de/0/com.topjohnwu.magisk/install/
  if [[ $API -lt 24 ]]; then
    INSTALL_PATH=/data/data/com.topjohnwu.magisk/install/
  fi
  run-as com.topjohnwu.magisk mkdir $INSTALL_PATH > /dev/null 2>&1
  if [[ $? -ne 0 ]] && [[ -n $HAS_ROOT ]]; then
    if [[ -n $HAS_ROOT ]]; then
      $SU "mkdir $INSTALL_PATH"
    else
      echo "[!] You are using release version of Magisk with non-root emulator "
      echo "[!] You might have problems using Magisk .. "
    fi
  else
    SU='run-as com.topjohnwu.magisk sh -c'
  fi
  $SU "cp -r $MAGISK_DIR/* $INSTALL_PATH"
  $SU "ls -l $INSTALL_PATH"
fi # USES_MANAGER

cleanup
