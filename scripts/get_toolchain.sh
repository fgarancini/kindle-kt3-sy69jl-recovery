#!/bin/bash
# Downloads the portable ARM GNU toolchain (10.3-2021.07) used to build the u-boot.
# It unpacks into its own folder, nothing is installed system-wide.
#
#   KB  working directory (default: $HOME/kindle-build)
set -e

KB=${KB:-$HOME/kindle-build}
URL="https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf.tar.xz"

mkdir -p "$KB"
cd "$KB"
curl -fsSL -o toolchain.tar.xz "$URL"
# make sure we really got an archive and not an HTML error page
file toolchain.tar.xz | grep -qiE 'XZ' || { echo "Download is not an XZ archive." >&2; exit 1; }
tar xf toolchain.tar.xz
rm -f toolchain.tar.xz
ls "$KB"
