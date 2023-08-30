#!/bin/bash

set -eo pipefail

CACHE_ROOT="$HOME/.cache/bazel"

QUIET=false
DOWNLOAD_ROOT="$CACHE_ROOT/downloads"
TOOLCHAIN_ROOT="$CACHE_ROOT/toolchain"
URLS=""
VENDOR=""
CPU="$(uname -m)"
MANIFEST=""
PRINT_ONLY=false

if [ -x "/usr/bin/lsb_release" ] ; then    
    PLATFORM="$(/usr/bin/lsb_release -a 2>/dev/null | grep Distributor | sed 's,^.*:,,' | awk '{ print $1 }' | tr '[:upper:]' '[:lower:]')"
    VENDOR="$(/usr/bin/lsb_release -a 2>/dev/null | grep Codename | awk '{ print $2 }' | tr '[:upper:]' '[:lower:]')"
elif [ "$(uname -s)" = "Darwin" ] ; then
    PLATFORM="macos"
    VENDOR="macos"
    LIBTOOL=glibtool
    LIBTOOLIZE=glibtoolize
elif [ -f /etc/os-release ] && cat /etc/os-release | grep -qi Oracle  ; then
    PLATFORM="oracle"
    VENDOR="ol$(cat /etc/os-release | grep -E ^VERSION= | awk -F= '{ print $2 }' | sed 's,",,g')"
fi


THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"
PPWD="$(pwd)"
TMPD="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"
mkdir -p "$TMPD"
trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}

# ---------------------------------------------------------------------------------------- show_help

show_help()
{
    EXEC="$(basename "$THIS_SCRIPT")"
    cat <<EOF

   Usage: $EXEC [OPTIONS...]* <toolchain>

      llvm toolchains are downloaded from github
      linux gcc toolchains from https://toolchains.bootlin.com, or brew on macos

   Options:

      -q|--quiet                   Quiet mode
      -d --download-dir <dirname>  Location of download directory; defaults ${DOWNLOAD_ROOT}
      -p|--prefix       <dirname>  Installation prefix for downloaded compiler; default ${TOOLCHAIN_ROOT}
      -u|--url         <url-base>  Url to load toolchains from (effect is cummulative)
      -v|--vendor        <string>  Overload the OS vendor. (Otherwise automatically determined.)
      -c|--cpu           <string>  Overload the cpu. (Otherwise automatically determined.)
      -m|--manifest    <filename>  Filename with a manifest of compiler versions+checksums
      --print-only                 Print information on selected options, and exit
            
   Examples:

      # Install the llvm-16 toolchain
      > $EXEC llvm-16

      # Install the llvm-15.0.6
      > $EXEC llvm-15.0.6

      # gcc12.2
      > $EXEC gcc-12.2

EOF
}

# ----------------------------------------------------------------------------------------- archives

archives()
{
    cat "$MANIFEST_FILE" | grep -Ev '^ *#?'
}

archive_line()
{
    archives | grep -i "$KERNEL" | grep -i "$CPU" | grep -i "$VERNDOR" | grep -i "$SELECT_TOOLCHAIN" | sort | tail -n 1
}

# ---------------------------------------------------------------------------------------------- gcc

lookup_archive()
{
    local ARCHIVE_LINE="$(archive_line)"
    if [ "$ARCHIVE_LINE" = "" ] ; then
        echo "Failed to find toolchain archive, toolchain: $SELECT_TOOLCHAIN, kernel: $KERNEL, cpu: $CPU, vendor: $VENDOR" 1>&2
        exit 1
    fi

    local FULL_VERSION="$(echo "$ARCHIVE_LINE" | awk '{ print $1 }')"
    local ARCHIVE="$(echo "$ARCHIVE_LINE" | awk '{ print $2 }')"   
    local HASHSUM="$(echo "$ARCHIVE_LINE" | awk '{ print $3 }')"   
    local URL_BASE="https://toolchains.bootlin.com/downloads/releases/toolchains/x86-64/tarballs"
    local URL="$URL_BASE/$ARCHIVE"
    local INSTALL_DIR="gcc-${FULL_VERSION}"
    
    echo "${INSTALL_DIR} ${URL} ${HASHSUM}"
}

# ------------------------------------------------------------------------------------ get file hash

get_file_hash()
{
    local FNAME="$1"
    local HASH_FNAME="$FNAME.sha256"
    if [ ! -f "$HASH_FNAME" ] ; then
        sha256sum "$FNAME" | awk '{ print $1 }' > "$HASH_FNAME"
    fi
    cat "$HASH_FNAME"
}

# --------------------------------------------------------------------------------- download archive

download_archive()
{
    local URL="$1"
    local HASH="$2"
    local FNAME="$(basename "$URL")"
    mkdir -p "$DOWNLOAD_ROOT"
    local DEST_FILE="$DOWNLOAD_ROOT/$FNAME"
    if [ -f "$DEST_FILE" ] && [ "$(get_file_hash "$DEST_FILE")" = "$HASH" ] ; then
        return 0 # We're winners!
    fi
    ! $QUIET && echo "downloading url: $DEST_FILE" || true
    wget $($QUIET && echo "" || echo "--show-progress") -O "$DEST_FILE" -o "$DEST_FILE.wget.log" "$URL"
    local FILE_HASH="$(get_file_hash "$DEST_FILE")"
    if [ "$FILE_HASH" != "$HASH" ] ; then
        echo "failed to validate hash, url: $URL, expected-hash: $HASH, file-hash: $FILE_HASH" 1>&2
        exit 1
    fi
}

# -------------------------------------------------------------------------------- install-toolchain

install_toolchain()
{
    local TOOLCHAIN="$1"
    local URL="$2"
    local EXPECTED_HASH="$3"
    local INSTALL_DIR="$TOOLCHAIN_ROOT/$TOOLCHAIN"
    local ARCHIVE="$DOWNLOAD_ROOT/$(basename "$URL")"


    if [[ "$ARCHIVE" == *.tar.xz ]] ; then
        EXTENSION=".tar.xz"
        ARCCMD="xz"
    else
        EXTENSION=".tar.bz2"
        ARCCMD="bzip2"
    fi
    local UNPACKED_DIRNAME="$(basename "$ARCHIVE" $EXTENSION)"
    local INSTALL_LOCK_FILE="$INSTALL_DIR/.install-complete.lock"
    
    ! $QUIET && echo "selecting toolchain: $TOOLCHAIN" || true

    if [ -f "$INSTALL_LOCK_FILE" ] ; then
        # Assume installtion completed successfully
        return 0
    fi
    
    # Ensure the toolchain directory
    if [ ! -d "$TOOLCHAIN_ROOT" ] ; then
        ! $QUIET && echo "creating toolchain root directory: $TOOLCHAIN_ROOT" || true
        mkdir -p "$TOOLCHAIN_ROOT"
        if [ ! -d "$TOOLCHAIN_ROOT" ] ;then
            echo "failed to create directory '$TOOLCHAIN_ROOT', aborting" \
                && exit 1
        fi
    fi

    # May need to nuke what was there
    if [ -d "$INSTALL_DIR" ] ; then
        ! $QUIET && echo "previous installation incomplete, deleting directory: $INSTALL_DIR" || true
        rm -rf "$INSTALL_DIR"
    fi
    
    # Grab the installation
    download_archive "$URL" "$EXPECTED_HASH"
    ! $QUIET && echo "unpacking archive: $ARCHIVE" || true

    # Untar it somewhere safe
    cat "$ARCHIVE" | $ARCCMD -dc | tar -C "$TMPD" -xf -

    # Move the installation into place, and place "install" lock file
    ! $QUIET && echo "finishing toolchain installation, install_dir: $INSTALL_DIR" || true
    ! mv "$TMPD/$UNPACKED_DIRNAME" "$INSTALL_DIR" \
        && echo "failed to install to '$INSTALL_DIR', aborting" \
        && exit 1
    echo "$EXPECTED_HASH" > "$INSTALL_LOCK_FILE"
}

# -------------------------------------------------------------------------------------- install-gcc

install()
{
    local ARCHIVE="$1"
    local HASHSUM="$2"

    
    
    local TOOLCHAIN="$(echo "$LINE" | awk '{ print $1}')"
    local URL="$(echo "$LINE" | awk '{ print $2}')"
    local EXPECTED_HASH="$(echo "$LINE" | awk '{ print $3}')"
    install_toolchain "$TOOLCHAIN" "$URL" "$EXPECTED_HASH"
}

# ------------------------------------------------------------------------------- parse command line

if (( "$#" == 0 )) ; then
    echo "no command-line arguments specifed; use -h|--help for help" 1>&2 && exit 1
fi

SELECT_TOOLCHAIN=""
while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
    [ "$ARG" = "-q" ] || [ "$ARG" = "--quiet" ] && QUIET=true && continue
    [ "$ARG" = "-d" ] || [ "$ARG" = "--download-dir" ] && DOWNLOAD_ROOT="$1" && shift && continue
    [ "$ARG" = "-p" ] || [ "$ARG" = "--prefix" ] && TOOLCHAIN_ROOT="$1" && shift && continue
    [ "$ARG" = "-u" ] || [ "$ARG" = "--url" ] && URLS+="$1 " && shift && continue
    [ "$ARG" = "-v" ] || [ "$ARG" = "--vendor" ] && VENDOR="$1 " && shift && continue
    [ "$ARG" = "-c" ] || [ "$ARG" = "--cpu" ] && CPU="$1 " && shift && continue
    [ "$ARG" = "-m" ] || [ "$ARG" = "--manifest" ] && MANIFEST="$1 " && shift && continue
    [ "$ARG" = "--print-only" ] && PRINT_ONLY=true && continue
    if [ "$SELECT_TOOLCHAIN" != "" ] ; then
        echo "Unexpected argument: '$ARG', aborting" 1>&2 && exit 1
    fi
    SELECT_TOOLCHAIN="$ARG"
done

HAS_ERROR=false
if [ "$KERNEL" != "Linux" ] && [ "$KERNEL" != "Darwin" ] ; then
    echo "Only supports Linux and Darwin kernels, Kernel: $KERNEL" 1>&2
    HAS_ERROR=true
fi

if [ "$CPU" != "x86_64" ] && [ "$CPU" != "arm64" ] ; then
    echo "Only supports x86_64 and arm64 cpus, Cpu: $CPU" 1>&2
    HAS_ERROR=true
fi

if [ "$VENDOR" = "" ] ; then
    echo "Failed to detector Vendor and it was not supplied" 1>&2
    HAS_ERROR=true
fi

if [ "$URLS" = "" ] ; then
    echo "No URLs were supplied" 1>&2
    HAS_ERROR=true
fi

if [ "$MANIFEST" = "" ] ; then
    echo "The manifest file was not supplied" 1>&2
    HAS_ERROR=true
elif [ ! -f "$MANIFEST" ] ; then
    echo "File not found, manifest file: $MANIFEST" 1>&2
    HAS_ERROR=true
fi

if [ "$SELECT_TOOLCHAIN" = "" ] ; then
    echo "No toolchain was selected" 1>&2
    HAS_ERROR=true
fi

if $HAS_ERROR ; then
    echo "aborting" 1>&2
    ! $PRINT_ONLY && exit 1
fi

ARCHIVE_LINE="$(archive_line)"
if [ "$ARCHIVE_LINE" = "" ] ; then
    echo "Failed to find toolchain archive, toolchain: $SELECT_TOOLCHAIN, kernel: $KERNEL, cpu: $CPU, vendor: $VENDOR" 1>&2
    ! $PRINT_ONLY && exit 1
fi

HASHSUM="$(echo "$ARCHIVE_LINE" | awk '{ print $1 }')"   
ARCHIVE="$(echo "$ARCHIVE_LINE" | awk '{ print $2 }')"
# TOOLCHAIN="$(echo "$ARCHIVE" | 

# ------------------------------------------------------------------------------------------- action

if $PRINT_ONLY ; then
    cat <<EOF
QUIET            $($QUIET && echo "true" || echo "false")
DOWNLOAD_ROOT    $DOWNLOAD_ROOT
TOOLCHAIN_ROOT   $TOOLCHAIN_ROOT
URLS             $URLS
VENDOR           $VENDORS
CPU              $CPU
MANIFEST         $MANIFEST
ARCHIVE          $ARCHIVE
HASHSUM          $HASHSUM
PRINT_ONLY       $($PRINT_ONLY && echo "true" || echo "false")
EOF
    exit 0
fi

install "$ARCHIVE" "$HASHSUM"

