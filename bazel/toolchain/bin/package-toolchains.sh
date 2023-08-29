#!/bin/bash

set -e

TOOLCHAINS_DIR="/opt/toolchains"
THIS_DIR="$(cd $(dirname "$0") ; pwd)"
LLVMS="llvm-16.0.6 llvm-15.0.7 llvm-14.0.6 llvm-13.0.1"
GCCS="gcc-13.2.0 gcc-12.3.0 gcc-11.4.0 gcc-10.5.0 gcc-9.5.0"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [build|archive] [<toolchain>|:all]

      Where toolchain can be one of:

         $LLVMS
         $GCCS
    
EOF
}

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
    VENDOR="ol$(cat /etc/os-release | grep -E ^VERSION= | awk -F= '{ print $2 }' | sed 's,",,g')"
else
    echo "Failed to determine platform" 1>&2 && exit 1
fi

archive_it()
{
    local TOOL="$1"
    local ARCHIVE="${TOOL}--x86_64--${VENDOR}--linux.tar.xz"
    cd "$TOOLCHAINS_DIR"
    tar -c "$TOOL" | xz -c9e > "${ARCHIVE}"
    sha256sum "$ARCHIVE" > "$ARCHIVE.sha256" 
}

build_it()
{
    local TOOL="$1"
    cd "$THIS_DIR"
    ./build-toolchain.sh --no-cleanup "$TOOL"    
}

DO_ARCHIVE=false
DO_BUILD=false
TOOLCHAIN=""

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

if (( $# == 0 )) ; then
    echo "Type -h for help" 1>&2 && exit 1
fi

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "build" ] && DO_BUILD=true && continue
    [ "$ARG" = "archive" ] && DO_ARCHIVE=true && continue
    if [ "$TOOLCHAIN" != "" ] ; then
        echo "unexpected argument: '$ARG', toolchain already set to '$TOOLCHAIN'" 1>&2
        exit 1
    fi
    TOOLCHAIN="$ARG"
done

TOOLCHAINS="$LLVMS $GCCS"
if [ "$TOOLCHAIN" != ":all" ] ; then
    # Check toolchain is in the list
    if ! echo "$TOOLCHAINS" | grep -q "$TOOLCHAIN" ; then
        echo "Unexpected toolchain: '$TOOLCHAIN'" 1>&2
        exit 1
    fi
    TOOLCHAINS="$TOOLCHAIN"
fi

if ! $DO_BUILD && ! $DO_ARCHIVE ; then
    echo "Must specify one of 'archive' or 'build' to actually do anything!" 1>&2
    exit 1
fi

for TOOL in $TOOLCHAINS ; do
    $DO_BUILD && build_it "$TOOL" || true
    $DO_ARCHIVE && archive_it "$TOOL" || true
done


