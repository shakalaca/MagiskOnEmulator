Install Magisk On Official Android Emulator
===========================================

Worked on Android API 22 - 27

0. Grab Magisk and rename to `magisk.zip` (in this directory)
* stable: https://github.com/topjohnwu/Magisk/releases/download/v18.1/Magisk-v18.1.zip
* canary: https://raw.githubusercontent.com/topjohnwu/magisk_files/master/canary_builds/magisk-debug.zip

1. Create new AVD and start.
2. Go avd directory (~/.android/avd/<your_avd_name>/) and open hardware-qemu.ini.
3. Find `disk.ramdisk.path` and copy the ramdisk.img to current directory, and set the value of `disk.ramdisk.path` to this file.
4. Clone this repository and copy the ramdisk.img to here.
5. Execute `patch.sh` or `patch.bat` to install Magisk on the ramdisk.img.
6. When finished copy the  patched `ramdisk.img` back to avd directory.
7. Restart (cold start) emulator *twice* and enjoy Magisk :)

