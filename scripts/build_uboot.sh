#!/bin/bash
# Builds MollySophia's imx6_android_u-boot_kindle for the Kindle KT3 (mx6sl_heisenberg)
# with a modern ARM GCC, by applying the patches in ../patches on a fresh clone.
#
#   ./build_uboot.sh               build with the build fixes only (0001)
#   THRESHOLD=1 ./build_uboot.sh   also apply 0002 (fastboot long-press window = 600 s)
#
# Variables (all optional):
#   KB   working directory            (default: $HOME/kindle-build)
#   SRC  where to clone the u-boot    (default: $KB/u-boot, must NOT exist yet)
#   TC   ARM toolchain directory      (default: $KB/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf,
#                                      see get_toolchain.sh)
set -e

KB=${KB:-$HOME/kindle-build}
SRC=${SRC:-$KB/u-boot}
TC=${TC:-$KB/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf}
PATCHES=$(cd "$(dirname "$0")/../patches" && pwd)

if [ -e "$SRC" ]; then
  echo "$SRC already exists. Remove it or set SRC to a new path." >&2
  exit 1
fi
if [ ! -x "$TC/bin/arm-none-linux-gnueabihf-gcc" ]; then
  echo "Toolchain not found in $TC (run get_toolchain.sh or set TC)." >&2
  exit 1
fi

git clone https://github.com/MollySophia/imx6_android_u-boot_kindle "$SRC"
cd "$SRC"

git apply --check "$PATCHES/0001-build-with-modern-gcc.patch"
git apply "$PATCHES/0001-build-with-modern-gcc.patch"
if [ -n "$THRESHOLD" ]; then
  git apply --check "$PATCHES/0002-fastboot-long-press-threshold-600s.patch"
  git apply "$PATCHES/0002-fastboot-long-press-threshold-600s.patch"
fi

export PATH="$TC/bin:$PATH"
CC=arm-none-linux-gnueabihf-
make ARCH=arm CROSS_COMPILE=$CC mx6sl_heisenberg_config
make ARCH=arm CROSS_COMPILE=$CC -j"$(nproc)"

ls -l u-boot.imx
sha256sum u-boot.imx
