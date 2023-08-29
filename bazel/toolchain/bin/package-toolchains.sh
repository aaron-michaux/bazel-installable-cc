#!/bin/bash

TOOLCHAINS_DIR="/opt/toolchains"

VENDOR=""
if [ -x "/usr/bin/lsb_release" ] ; then    
    PLATFORM="ubuntu"
    VENDOR="$(/usr/bin/lsb_release -a 2>/dev/null | grep Codename | awk '{ print $2 }')"
elif [ -f "/etc/fedora-release" ] ; then
    PLATFORM="fedora"
    echo "Not setup for Fedora, sorry!" 1>&2 && exit 1
elif [ "$(uname -s)" = "Darwin" ] ; then
    PLATFORM="macos"
    LIBTOOL=glibtool
    LIBTOOLIZE=glibtoolize
    echo "Not setup for Darwin, sorry!" 1>&2 && exit 1
elif [ -f /etc/os-release ] && cat /etc/os-release | grep -qi Oracle  ; then
    PLATFORM="oracle"
    VENDOR="$(cat /etc/os-release | grep -E ^VERSION= | awk -F= '{ print $2 }' | sed 's,",,g')"
else
    echo "Failed to determine platform" 1>&2 && exit 1
fi

archive_it()
{
    local TOOL="$1"
    local ARCHIVE="${TOOL}--x86_64--${VENDOR}--linux.tar.xz"
    tar -c "$TOOL" | xz -c9e > "${ARCHIVE}"
    sha256sum "$ARCHIVE" > "$ARCHIVE.sha256" 
}

THIS_DIR="$(cd $(dirname "$0") ; pwd)"
LLVMS="llvm-16.0.6 llvm-15.0.7 llvm-14.0.6 llvm-13.0.1"
GCCS="gcc-13.2.0 gcc-12.3.0 gcc-11.4.0 gcc-10.5.0 gcc-9.5.0"
for TOOL in $LLVMS $GGCS ; do
    cd "$THIS_DIR"
    ./build-toolchain.sh --no-cleanup "$TOOL"
    cd "$TOOLCHAINS_DIR"
    wait
    archive_it "$TOOL" &
done     

