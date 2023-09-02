#!/bin/bash

set -e

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"
source "$SCRIPT_DIR/platform.sh"

LLVMS="llvm-16.0.6 llvm-15.0.7 llvm-14.0.6 llvm-13.0.1"
GCCS="gcc-13.2.0 gcc-12.3.0 gcc-11.4.0 gcc-10.5.0 gcc-9.5.0"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [build|archive] [<toolchain>|:all]

      Where toolchain can be one of:

         $LLVMS
         $GCCS
    
      If 'archive' is done without 'build', then all archive
      jobs are done in parallel.

EOF
}

archive_it()
{
    local TOOL="$1"
    local TOOLROOT="${TOOL}--${MACHINE}--${VENDOR_TAG}--${PLATFORM}"
    local ARCHIVE="${TOOLROOT}.tar.xz"
    cd "$TOOLCHAINS_DIR"
    if [ ! -d "$TOOLROOT" ] ; then
        echo "archive $TOOLROOT, skipping (directory missing)"
        return 0
    elif [ -f "$ARCHIVE.sha256" ] ; then
        if [ "$(sha256sum "$ARCHIVE")" = "$(cat $ARCHIVE.sha256)" ] ; then
            echo "archive $TOOLROOT, skipping (already done)"
            return 0
        fi
    fi
    echo "archive $TOOLROOT"
    tar -c "$TOOLROOT" | xz -c9e > "$ARCHIVE"
    sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
}

build_it()
{
    local TOOL="$1"
    cd "$SCRIPT_DIR"
    echo "build $TOOL"
    ./build-toolchain.sh $CLEANUP_ARG "$TOOL"    
}

DO_ARCHIVE=false
DO_BUILD=false
TOOLCHAIN=""
CLEANUP_ARG=

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
    [ "$ARG" = "--cleanup" ] && CLEANUP_ARG="$ARG" && continue
    [ "$ARG" = "--no-cleanup" ] && CLEANUP_ARG="$ARG" && continue
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

    if $DO_ARCHIVE ; then
        if $DO_BUILD ; then
            archive_it "$TOOL"
        else
            archive_it "$TOOL" &
        fi        
    fi
done

wait

echo "all jobs complete"

