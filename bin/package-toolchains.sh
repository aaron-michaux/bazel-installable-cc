#!/bin/bash

set -euo pipefail

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"
source "$SCRIPT_DIR/platform.sh"

LLVMS="llvm-17.0.6 llvm-16.0.6 llvm-15.0.7 llvm-14.0.6 llvm-13.0.1 llvm-12.0.1"
GCCS="gcc-13.2.0 gcc-12.3.0 gcc-11.4.0 gcc-10.5.0 gcc-9.5.0"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [build|archive] [<toolchain>|:all]

      Where toolchain can be one of:

         $LLVMS
         $GCCS
    
   Examples:

      # Build and archive four toolchains; the archive step is done in parallel
      > $(basename $0) build archive llvm-17.0.6 llvm-16.0.6 llvm-15.0.7 llvm-14.0.6

EOF
}

archive_it()
{
    local TOOL="$1"
    local TOOLROOT="${TOOL}--${MACHINE}--${VENDOR_TAG}--${PLATFORM}"
    local ARCHIVE="${TOOLROOT}.tar.xz"
    mkdir -p "$TOOLCHAINS_DIR"
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
    TOOLCHAIN+=" $ARG"
done

TOOLCHAINS="$LLVMS $GCCS"
if [ "$TOOLCHAIN" != ":all" ] ; then
    # Check toolchain is in the list
    for ARG in $TOOLCHAIN ; do
        if ! echo "$TOOLCHAINS" | grep -q "$ARG" ; then
            echo "Unexpected toolchain: '$ARG'" 1>&2
            exit 1
        fi
    done
    # Could be more than one
    TOOLCHAINS="$TOOLCHAIN"
fi

if ! $DO_BUILD && ! $DO_ARCHIVE ; then
    echo "Must specify one of 'archive' or 'build' to actually do anything!" 1>&2
    exit 1
fi

HAS_ERROR="false"
if $DO_BUILD ; then
    for TOOL in $TOOLCHAINS ; do
        build_it "$TOOL" || HAS_ERROR="true"
    done
fi

if $DO_ARCHIVE && ! $HAS_ERROR ; then
    for TOOL in $TOOLCHAINS ; do
        archive_it "$TOOL" &
    done
    wait
fi

echo "all jobs complete"

