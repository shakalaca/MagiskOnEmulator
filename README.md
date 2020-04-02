Install Magisk On Official Android Emulator
===========================================

Worked on Android API 22 - 29 (except 28)

1. Create new AVD and copy `ramdisk.img` from `<sdk_home>/system-images/<platform>/*/ramdisk.img`
2. Clone this repository and copy the `ramdisk.img` to here.
3. Starts newly created AVD.
4. Execute `patch.sh` or `patch.bat` to install Magisk on the ramdisk.img.
5. When finished copy the patched `ramdisk.img` back to AVD directory.
6. Restart (cold start) emulator and enjoy Magisk :)

Install Magisk On Android x86 Project on VirtualBox
===================================================

Only test on Android 8.1

0. Grab Magisk.zip and put in this directory.
1. Bring up Android system and establish adb connection.
2. Execute `prepare_image.sh` or `prepare_image.bat` to grab initrd.img and ramdisk.img on hard drive.[B
3. Execute `patch.sh` or `patch.bat` to patch initrd.img and ramdisk.img
4. Execute `install_vbox.sh` or `install_vbox.bat` to install patched images on hard drive.
5. Restart machine and enjoy Magisk :)
