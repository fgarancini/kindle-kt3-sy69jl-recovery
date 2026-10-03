# Recovering a Kindle Basic 8th gen (SY69JL / KT3) stuck on the "tree with the kid" boot logo

A write-up of one real case (October 2026). A 10-year-old Kindle was **frozen on the boot screen** (the "kindle" logo on top and the tree-with-a-kid picture below). The PC didn't detect it and no reboot or charge helped. It was fully recovered from Windows 10 **without any soldering**, and then jailbroken.

> **Read the whole thing before starting.** This flashes the bootloader and system of your Kindle using third-party tools and files. If your device still works, don't do this. If it's already dead, the risk is low. Nothing here is guaranteed to work on your unit; it is a single case.

Español: [README.es.md](README.es.md)

## Repository contents

| Path | What it is |
|---|---|
| `patches/0001-build-with-modern-gcc.patch` | Fixes to build MollySophia's u-boot with a modern GCC (applies on upstream `cc580e3`). |
| `patches/0002-fastboot-long-press-threshold-600s.patch` | Raises the fastboot long-press window from 15 s to 600 s. |
| `scripts/get_toolchain.sh` | Downloads the portable ARM GCC 10.3 used to build. |
| `scripts/build_uboot.sh` | Clones the upstream u-boot, applies the patches and builds `u-boot.imx` (`THRESHOLD=1` also applies 0002). |
| `scripts/fix_fastboot_guid.ps1` | Windows (admin): sets the Android interface GUID so Google's `fastboot.exe` sees the device. |
| Releases → `u-boot-threshold600.imx` | The binary that was loaded on the Kindle (see the release notes). |

---

## 0. TL;DR

1. Try **another USB cable** (one that carries data). In this case the first cable only charged, which is why the PC "detected nothing".
2. With a good cable the Kindle shows up in Windows as **`VID_15A2 & PID_0063`** = **i.MX6SL** processor in *Serial Download Mode* (SDP). That means the CPU is alive and the device is recoverable over USB.
3. It was **not** the battery, and there is no "BIOS" to flash on a Kindle.
4. Load over USB a **u-boot with fastboot** (MollySophia's, **recompiled with a larger long-press threshold**).
5. With fastboot, flash a **bootloader** and the **stock firmware partitions** (CracKdroid package `kindle8.230118.zip`).
6. The system boots but the home screen stays blank: fixed by dropping an empty **`DO_FACTORY_RESTORE`** file in the root.
7. The setup wizard appears and the Kindle works again.
8. Optional: **KindleBreak** jailbreak (firmware 5.12.2) + Hotfix + KUAL. KUAL wouldn't open until **`;log mrpi`** was typed in the search bar.
9. `.epub` files are **not** supported by this firmware: convert to `.azw3` with Calibre.
10. Real time spent: several hours, mostly waiting for fastboot windows that last a few seconds.

---

## 1. Device and symptoms

| Item | Value |
|---|---|
| Model | **SY69JL** = Kindle Basic 8th generation (2016), 6", touch. The community calls it **KT3** |
| Symptom | Frozen on the boot logo (kindle + tree with the kid) |
| PC | Didn't see it as a drive or as anything |
| 40-second forced restart and charging | Didn't help |
| Firmware installed afterwards | Kindle 5.12.2 |

---

## 2. What it was NOT

- **The battery:** suspected first. With a good cable the CPU enumerated over USB, so there was enough power. The battery is still old (compatible replacement: **58-000083**, 890 mAh) but it wasn't the cause of the freeze.
- **"BIOS flash":** doesn't exist on a Kindle. The equivalent is flashing bootloader/partitions over USB, which is what was done.
- **Jailbreak as a fix:** a jailbreak needs a working system. It comes *after* recovery.

---

## 3. Diagnosis: the cable first

Try **two or three cables and different ports**. Some cables are charge-only.

With a good cable, Device Manager (or PowerShell) showed:

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB\VID*' }
# -> USB Input Device   USB\VID_15A2&PID_0063\...
```

`15A2` is NXP/Freescale and `0063` is **i.MX6SL in download mode (SDP)**. Confirmed with `uuu`:

```
uuu.exe -lsusb      ->   MX6SL  SDP:  0x15A2  0x0063
```

If you see that, the CPU is fine and the problem is in the bootloader/storage: it's recoverable.

---

## 4. Tools and files used

- **Windows 10** (Home is fine), PowerShell.
- **uuu (NXP Universal Update Utility)** – `uuu.exe` from https://github.com/nxp-imx/mfgtools/releases (1.5.243 was used). It recognised the MX6SL with no extra drivers.
- **Google platform-tools** (`fastboot.exe`).
- **Google USB driver** (`usb_driver_r13-windows.zip`, contains `android_winusb.inf`).
- **Zadig** (to install WinUSB for the fastboot device of the first u-boot).
- **WSL with Ubuntu** and a portable ARM compiler (`gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf`) to build u-boot.
- **MollySophia's u-boot:** https://github.com/MollySophia/imx6_android_u-boot_kindle
- **CracKdroid package** `kindle8.230118.zip` (from https://github.com/Ooonana/Guide-to-installing-android-on-kindle, *Releases* section). It contains `restore.img`, `userdata.bin`, `diagsys.bin`, `diagkern.bin`, `kernel.bin`, `system.bin` (stock 2019 firmware) and a `fastdownload.bat` script. The original site (kdroid.club) and the Telegram channel no longer exist.
- **Calibre** (to convert books).

### Antivirus warning
Windows Defender flagged the zip as **`Trojan:Script/Phonzy.A!ml`** (a heuristic/machine-learning detection; I suspect a false positive because of the Chinese `.bat` scripts, but **I can't guarantee that**). The whole script was read before use: it only calls `fastboot` and `adb` and doesn't touch anything outside its folder. `fastdownload.exe` is a **closed-source, unsigned** binary. If that bothers you, do it on a spare PC.
A **Defender exclusion for one dedicated folder** was used and removed at the end. Don't leave permanent exclusions.

---

## 5. Step by step

### 5.1 Build u-boot with a larger threshold

In this u-boot, fastboot via the button is triggered by **two long power-button presses within `LP_FASTBOOT_THRESHOLD` seconds** ("LP" here means *long press*, not *low power*). The default is 15 s, impossible to meet while loading over USB. Raise it to 600:

```
board/freescale/mx6sl_heisenberg/pmic_rohm.c
#define LP_FASTBOOT_THRESHOLD   600
```

That u-boot is from 2013 and doesn't build as-is with a modern GCC. These fixes were needed:

```bash
# 1) missing header for the compiler version
cp include/linux/compiler-gcc4.h include/linux/compiler-gcc10.h   # (and 5..13)

# 2) "extern inline" in headers -> static inline
grep -rl '^extern inline' --include=*.h . | xargs sed -i 's/^extern inline/static inline/'

# 3) "__something" functions with a weak alias declared inline -> drop the inline
grep -rlE '^(void|int|ulong|unsigned long) +inline +__' --include=*.c common drivers lib net fs disk arch/arm board/freescale api \
  | xargs sed -i -E 's/^(void|int|ulong|unsigned long) +inline +__/\1 __/'
grep -rlE '^inline +[a-z_ ]+ +__' --include=*.c common drivers lib net fs disk arch/arm board/freescale api \
  | xargs sed -i -E 's/^inline +([a-z_ ]+ +__)/\1/'

# build
export PATH=/path/to/gcc-arm-10.3.../bin:$PATH
make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- mx6sl_heisenberg_config
make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf-
# result: u-boot.imx (~360 KB)
```

(`apt` in that WSL distro was broken; this was avoided by unpacking the portable compiler into its own folder.)

### 5.2 Getting from SDP mode to fastboot

A single `uuu` load **did not work twice in a row**. What worked:

1. Forced restart (**hold power for 40 s**) with the cable connected. *(The 40 s applies only to this step of loading u-boot over SDP; the flashing step, see 5.4, works differently.)*
2. `uuu.exe SDP: boot -f u-boot-threshold600.imx` → **first load** (can take ~30 s; with a good cable sometimes 8 s).
3. Another 40 s forced restart.
4. **Second load** with the same command (within 10 minutes).
5. A **`VID_1949 & PID_D0D0`** device appears (fastboot).

### 5.3 Fastboot driver

The first device (`1949:D0D0`) showed up "in Error". **WinUSB was installed with Zadig.** But Google's `fastboot.exe` looks for the Android interface GUID, not the random one Zadig uses, so **it didn't see the device**. Fixed by changing this in the registry (as administrator):

```
HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_1949&PID_D0D0\<serial>\Device Parameters
DeviceInterfaceGUIDs = {F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}
```

After that `fastboot devices` lists the device.

> **Mind the cable:** with the first cable fastboot enumerated but writes failed with `AdbWriteEndpointSync failed ... semaphore timeout`. With another cable it answered instantly.

### 5.4 Flashing

```
fastboot flash bootloader restore.img      # package bootloader (208 KB)
fastboot reboot
```

After that the Kindle showed, **once**, the official screen *"The Kindle needs repair ... J5_ROOTFS_REPARTITIONING"* and appeared as a USB drive: the new bootloader worked.

> **This phase is NOT "hold the button for 40 s and it works".** After flashing `restore.img`, the Kindle only exposes fastboot for **~8 seconds on each boot**, and each window accepts **a single command**. The key was to **keep the device in a constant reboot loop** (here, by using the power button to force resets) while **a script that was already running and polling USB** caught the window and fired one `fastboot flash` before it closed. Several attempts failed mid-transfer and had to be repeated on the next window. In practice: a script that waits for the device and runs *one* command, while you keep the device rebooting by hand.

While the system is still broken, the new bootloader **opens a ~8 s fastboot window on every boot** (`VID_18D1 & PID_4E40`, "Android Bootloader Interface"). To make Windows recognise it, Google's official driver was installed (as administrator):

```
pnputil /add-driver android_winusb.inf /install
```

And **one command per window** was flashed (automated with a script that waited for the window and fired the command):

```
fastboot flash userdata     userdata.bin     # 64 MB
fastboot flash diags        diagsys.bin      # 64 MB
fastboot flash diags_kernel diagkern.bin     # 8 MB
fastboot flash kernel       kernel.bin       # 5 MB
fastboot flash system       system.bin       # 460 MB (~2 min upload + 20 s write)
```

Some attempts failed because the window closed mid-transfer; they were retried until they completed.

Notes on `fastdownload.exe` (the package's own flasher):
- It writes `cache` (from `data.bin`), `kernel` and `system`, but it **hangs** at 100 % CPU if the window closes. That's why it was done by hand with `fastboot`.
- `config.bin` (contains `newkindle8`) is **not a partition** (`flash config` returns `partition does not exist`). It probably just checks the device type; that's an assumption.

### 5.5 Once the system boots: the "double long press"

Once the system boots, **the fastboot window no longer opens by itself**. To get back, do **two long presses** of the power button:

1. Hold ~10 s until it restarts, release.
2. **As soon as the logo with the tree appears**, hold again ~10 s, release.

The window opens ~20 s later. If the second press comes after the system has loaded, it doesn't work.

### 5.6 Blank home screen → `DO_FACTORY_RESTORE`

The system booted (lock screen, power menu, Wi-Fi and keyboard worked) but **the home screen never drew**. Fix, from a MobileRead thread:

1. Connect the Kindle over USB.
2. Create an **empty file named `DO_FACTORY_RESTORE`** in the root (next to `documents`).
3. Eject, unplug and restart.

Result: the **setup wizard** appeared (language selection) and everything worked. There was also a 0-byte `update.bin.tmp.partial` in the root: the Kindle had tried to download a mandatory update and received no data.

---

## 6. Jailbreak (optional)

Firmware **5.12.2** + KT3 → compatible with **KindleBreak** (supports 5.10.3 to 5.13.3; it does **not** work on 5.12.2.2). It is done **without Wi-Fi**.

1. Turn **Airplane mode** on and keep it on.
2. From https://kindlemodding.org/jailbreaking/Legacy/KindleBreak/ download `jb-kindlebreak.zip` (MD5 `0215c36cc1e3ad8136a67daebe369452`) and `file__0.localstorage`.
3. Unzip into the Kindle root and copy `file__0.localstorage` to `/.active_content_sandbox/browser/resource/LocalStorage/`.
4. Eject and open the **Experimental Browser**; the device freezes, reboots by itself (a "Kindle Feedback" window shows up) and ends up jailbroken.
5. Verify: `kindlebreak_log.txt` appears in the root with `Created developer key (0)`, and the exploit files delete themselves.

**Hotfix:** copy `Update_hotfix_universal.bin` (https://github.com/KindleModding/Hotfix/releases) to the root → *Settings → ⋮ → Update Your Kindle* → then open the **"Run Hotfix"** item in the library.

**KUAL (it worked, but there is one step that's easy to miss):** `KUAL.sh` and `KUAL.jar` (PEKI) were copied to `documents` and the `extensions` and `mrpackages` folders (MRPI) to the root. `KUAL.sh` installed itself (the `.jar` deleted itself, which is normal), but opening it showed "Opening…", the cover went black and it returned to the library, even after a reboot.

**Fix:** type exactly **`;log mrpi`** in the library **search bar** and tap search. A message ("Hush little baby…") appears with flashing icons, the screen flickers and returns to the library. After that **KUAL opened fine**. This is the step that install guides take for granted and that was skipped here until the end. (It isn't confirmed whether that exact command fixed it or whether elapsed time helped; but it was the last thing changed before it worked.)

With KUAL working you can now **block automatic updates** (the *Rename OTA Binaries* extension → *Rename*) and install KOReader.

**To keep the jailbreak**, leave Airplane mode on: if you connect to Wi-Fi it may update itself.

---

## 7. Loading books

This firmware **does not open `.epub`**. Convert with Calibre:

```
ebook-convert "book.epub" "book.azw3"
```

Copy the `.azw3` (or `.mobi`) to `documents`. `.pdf` files open directly.

---

## 8. Lessons and traps

- **The cable mattered twice** (detection and USB writes). Try several.
- **Each fastboot command needs its own ~8 s window**: automate it with a script that waits for the device, and keep the device rebooting until it catches one. Timing is everything.
- **A 40 s forced restart between u-boot loads** was needed; without it the second load failed with `LIBUSB_ERROR_IO`.
- **Don't run anything you haven't read.** `fastdownload.bat`, `jb.sh` and `rename.sh` were read here; the closed `.exe` files could not be audited.
- The initial hypothesis (battery) was **wrong**: don't settle for the first explanation.
- With a dead device and nothing to lose the risk is low. If it still works, leave it alone.

---

## 9. What I don't know / didn't verify

- Why the first boot with the new bootloader showed the repair screen and later ones didn't.
- Why the home screen stayed blank before `DO_FACTORY_RESTORE` (a missing component was suspected; the real cause wasn't confirmed).
- Whether `;log mrpi` was exactly what fixed KUAL (see section 6); it was the last thing changed before it opened.
- Whether other SY69JL units with the same fault will respond the same way. One case only.

---

## 10. References

- MobileRead – KT3 Debricking: https://www.mobileread.com/forums/showthread.php?t=355003
- MobileRead – KT3 demo mode / `DO_FACTORY_RESTORE`: https://www.mobileread.com/forums/showthread.php?t=345733
- MobileRead – KT2 `imx_usb` similar case: https://www.mobileread.com/forums/showthread.php?t=350510
- Kindle KT3 u-boot (MollySophia): https://github.com/MollySophia/imx6_android_u-boot_kindle
- CracKdroid package / guide: https://github.com/Ooonana/Guide-to-installing-android-on-kindle
- uuu (NXP): https://github.com/nxp-imx/mfgtools
- KindleModding (jailbreak): https://kindlemodding.org/jailbreaking/
- KindleBreak: https://www.mobileread.com/forums/showthread.php?t=338268
