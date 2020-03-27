Install Magisk On Official Android Emulator
===========================================

Worked on Android API 22 - 29 (except 28)

1. Create new AVD and copy `ramdisk.img` from `<sdk_home>/system-images/<platform>/*/ramdisk.img`
2. Clone this repository and copy the `ramdisk.img` to here.
3. Starts newly created AVD.
4. Execute `patch.sh` or `patch.bat` to install Magisk on the ramdisk.img.
5. When finished copy the patched `ramdisk.img` back to AVD directory.
6. Restart (cold start) emulator and enjoy Magisk :)
