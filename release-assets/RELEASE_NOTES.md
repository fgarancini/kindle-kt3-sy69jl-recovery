# u-boot-threshold600.imx

u-boot for the Kindle Basic 8th gen (KT3, SY69JL), i.MX6SL, `mx6sl_heisenberg_config`, with the
fastboot long-press window raised from 15 s to 600 s so it can be reached while loading over SDP
with `uuu` (`uuu SDP: boot -f u-boot-threshold600.imx`).

**SHA-256:** `d492e18f5c4e79297143a34538d37e7fc5999b217d86b59f5d53a8666a92f571` (360 448 bytes)

## Source (u-boot is GPL)

- Upstream: https://github.com/MollySophia/imx6_android_u-boot_kindle at commit
  `cc580e34de5a4d30c842bf0f79cb39d816f983d4`
- Plus `patches/0001-build-with-modern-gcc.patch` and `patches/0002-fastboot-long-press-threshold-600s.patch` from this repository.
- Toolchain: Arm GNU 10.3-2021.07 (`arm-none-linux-gnueabihf`).

To reproduce: `THRESHOLD=1 scripts/build_uboot.sh`.

## What was and wasn't tested

- This exact binary was loaded on **one** KT3 and reached fastboot. It needed a 40 s forced restart
  between the two loads; see the guide.
- Rebuilding with `scripts/build_uboot.sh` on a fresh clone gives a `u-boot.imx` of the **same size**
  (360 448 bytes) with the threshold at 600, but **not a bit-identical file** (build timestamps and paths
  are embedded). The rebuilt file has not been flashed.
- Use at your own risk. Nothing here is guaranteed to work on other units.
