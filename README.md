Install Magisk On Official Android Emulator
===========================================

Works on Android API 22 - 30 (except 28)

1. For patching the ramdisk with magisk, your AVD must be already created
2. Make sure you backup the untouched `ramdisk.img` from `<sdk_home>/system-images/<platform>/*/ramdisk.img`. You will need it everytime you want to patch ramdisk with magisk (for the first time and also for subsequent magisk updates).
3. Clone this repository and copy the original `ramdisk.img` into the clone's folder.
4. Start the newly created AVD.
5. Execute `patch.sh` or `patch.bat` to install Magisk on the ramdisk.img (you can execute `patch.sh canary` or `patch.bat canary` to install latest canary Magisk on the ramdisk.img)
6. When finished, copy the patched `ramdisk.img` back to AVD directory.
7. Restart (cold start) emulator
8. Recommended: update magisk manager
9. Enjoy Magisk :)

Install Magisk On Android x86 Project on VirtualBox
===================================================

Only test on Android 8.1

0. Grab Magisk.zip and put in this directory.
1. Bring up Android system and establish adb connection.
2. Execute `prepare_image.sh` or `prepare_image.bat` to grab initrd.img and ramdisk.img on hard drive.
3. Execute `patch_vbox.sh` or `patch_vbox.bat` to patch initrd.img and ramdisk.img
4. Execute `install_vbox.sh` or `install_vbox.bat` to install patched images on hard drive.
5. Restart machine and enjoy Magisk :)

Reference: https://github.com/topjohnwu/Magisk/issues/2551#issuecomment-608998420
