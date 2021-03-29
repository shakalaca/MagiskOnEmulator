Install Magisk On Official Android Emulator
===========================================

Works on Android API 22 - 30,S (except 28)

1. Make sure you backup the untouched `ramdisk.img` from `<sdk_home>/system-images/<platform>/*/ramdisk.img`. You will need it everytime you want to patch ramdisk with magisk (for the first time and also for subsequent magisk updates).
2. Copy the original `ramdisk.img` into this folder as
   `ramdisk.img.original`
3. Start the newly created AVD.
4. There are three ways to patch ramdisk:
  * Execute `patch.sh` to install Magisk (pre-downloaded) on the ramdisk.img
  * Alternatively, you can execute `patch.sh canary` to install latest canary Magisk on the ramdisk.img. This requires AVD internet connectivity towards github.
  * If you prefer patching by MagiskManager, execute `patch.sh manager`, it will create a fake `boot.img` on internal storage. We then launch MagiskManager and click `Install` and select `boot.img` to patch it. When finished,
execute `patch.sh pull` or `patch.bat pull` to get the patched ramdisk.img. This method is mainly for Released version of Magisk.

5. When finished, copy the patched `ramdisk.img.patched` back to AVD directory.
6. Power off and restart (cold start) the emulator
7. Recommended: update magisk manager
8. Enjoy Magisk :)

Sources
=======
busybox binary : https://github.com/Magisk-Modules-Repo/busybox-ndk

Notes
=====
| Emulator Version | command-line patch | manager patch
| ---- | ---- | ---- |
| Android S | Canary (22001) | Canary (22001, w/ built-in `su`) |
| Android 22 - 30 | Canary (22001) | 21.4 (w/ manager 8.0.7) |

MagiskManager 8.0.7: https://github.com/topjohnwu/Magisk/releases/download/manager-v8.0.7/MagiskManager-v8.0.7.apk

Magisk 21.4 channel url: https://bit.ly/304BAei (https://github.com/topjohnwu/magisk_files/blob/b0694fad863d3a15c6a2276b1061a280ece80ed7/stable.json)

Magisk 22001 Canary: https://github.com/topjohnwu/magisk_files/raw/c34d91edab45e140753e1256f2b694eed90d2dcc/app-debug.apk
