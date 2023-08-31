#!/bin/bash

set -eo pipefail

CACHE_ROOT="$HOME/.cache/bazel"

QUIET=false
DOWNLOAD_DIR="$CACHE_ROOT/toolchains/downloads"
INSTALL_PREFIX="$CACHE_ROOT/toolchains"
URLS=""
VENDOR=""
KERNEL="$(uname -s)"
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
      -d --download-dir <dirname>  Location of download cache directory; defaults ${DOWNLOAD_DIR}
      -p|--prefix       <dirname>  Installation prefix for downloaded compiler; default ${INSTALL_PREFIX}
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
    if [ -f "$MANIFEST" ] ; then
        cat "$MANIFEST" | grep -Ev '^ *#' | grep -Ev '^ *$' || true
    else
        echo
    fi
}

archive_line()
{
    archives | grep -i "$KERNEL" | grep -i "$CPU" | grep -i "$VENDOR" | grep -i "$SELECT_TOOLCHAIN" | tail -n 1 || true
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
    local ARCHIVE="$1"
    local EXPECTED_HASH="$2"
    
    mkdir -p "$DOWNLOAD_DIR"
    local DEST_FILE="$DOWNLOAD_DIR/$ARCHIVE"
    if [ -f "$DEST_FILE" ] ; then
        if [ "$(get_file_hash "$DEST_FILE")" = "$EXPECTED_HASH" ] ; then
            return 0 # We're winners!
        fi
    fi

    for URL in $URLS ; do
        rm -f "$DEST_FILE" # There could have been an incomplete download
        ! $QUIET && echo "Downloading url: $URL/$ARCHIVE" || true
        if wget $($QUIET && echo "" || echo "--show-progress") -O "$DEST_FILE" -o "$DEST_FILE.wget.log" "$URL/$ARCHIVE"
        then
            
            true # all is good
        else
            echo "Download failed, url: $URL/$ARCHIVE" 1>&2
            continue
        fi
        local FILE_HASH="$(get_file_hash "$DEST_FILE")"
        if [ "$FILE_HASH" != "$EXPECTED_HASH" ] ; then
            echo "Failed to validate hash, url: $URL/$ARCHIVE, expected-hash: $EXPECTED_HASH, file-hash: $FILE_HASH" 1>&2
        else            
            return 0 # We're winners!
        fi
    done

    echo "Failed to download '$ARCHIVE' from urls: $URLS, aborting" 1>&2
    exit 1
}

# -------------------------------------------------------------------------------- install-toolchain

install_toolchain()
{
    local ARCHIVE="$1"
    local EXPECTED_HASH="$2"
    local TOOLCHAIN="$(basename "$ARCHIVE" .tar.xz)"

    local INSTALL_DIR="$INSTALL_PREFIX/$TOOLCHAIN"
    local INSTALL_LOCK_FILE="$INSTALL_DIR/.install-complete.lock"
    
    ! $QUIET && echo "Selecting toolchain: $TOOLCHAIN" || true

    if [ -f "$INSTALL_LOCK_FILE" ] ; then
        local LOCKFILE_HASH="$(cat "$INSTALL_LOCK_FILE" | awk '{ print $1 }')"
        if [ "$LOCKFILE_HASH" != "$EXPECTED_HASH" ] ; then
            echo "Installation corruption; Lock file exits, '$INSTALL_LOCK_FILE', with hash '$LOCKFILE_HASH'; however, the expected hash was '$EXPECTED_HASH" 1>&2
            exit 1            
        fi        
        # Assume installtion completed successfully
        return 0
    fi
    
    # Ensure the toolchain directory
    if [ ! -d "$INSTALL_PREFIX" ] ; then
        ! $QUIET && echo "Creating toolchain install prefix: $INSTALL_PREFIX" || true
        mkdir -p "$INSTALL_PREFIX"
        if [ ! -d "$INSTALL_PREFIX" ] ;then
            echo "Failed to create directory '$INSTALL_PREFIX', aborting" 1>&2 && exit 1
        fi
    fi

    # May need to nuke what was there
    if [ -d "$INSTALL_DIR" ] ; then
        ! $QUIET && echo "Previous installation incomplete, deleting directory: $INSTALL_DIR" || true
        rm -rf "$INSTALL_DIR"
    fi
    
    # Grab the installation
    download_archive "$ARCHIVE" "$EXPECTED_HASH"
    
    # Untar it somewhere safe
    ! $QUIET && echo "Unpacking archive: $ARCHIVE" || true
    cat "$DOWNLOAD_DIR/$ARCHIVE" | xz -dc | tar -C "$TMPD" -xf -

    # Move the installation into place, and place "install" lock file
    ! $QUIET && echo "Finishing toolchain installation: $INSTALL_DIR" || true
    ! mv "$TMPD/$TOOLCHAIN" "$INSTALL_PREFIX" \
        && echo "failed to install to '$INSTALL_PREFIX', aborting" \
        && exit 1
    echo "$EXPECTED_HASH" > "$INSTALL_LOCK_FILE"
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
    [ "$ARG" = "-d" ] || [ "$ARG" = "--download-dir" ] && DOWNLOAD_DIR="$1" && shift && continue
    [ "$ARG" = "-p" ] || [ "$ARG" = "--prefix" ] && INSTALL_PREFIX="$1" && shift && continue
    [ "$ARG" = "-u" ] || [ "$ARG" = "--url" ] && URLS+="$1 " && shift && continue
    [ "$ARG" = "-v" ] || [ "$ARG" = "--vendor" ] && VENDOR="$1" && shift && continue
    [ "$ARG" = "-c" ] || [ "$ARG" = "--cpu" ] && CPU="$1" && shift && continue
    [ "$ARG" = "-m" ] || [ "$ARG" = "--manifest" ] && MANIFEST="$1" && shift && continue
    [ "$ARG" = "--print-only" ] && PRINT_ONLY=true && continue
    if [ "$SELECT_TOOLCHAIN" != "" ] ; then
        echo "Unexpected argument: '$ARG', aborting" 1>&2 && exit 1
    fi
    SELECT_TOOLCHAIN="$ARG"
done

HAS_ERROR=false
if [ "$KERNEL" != "Linux" ] && [ "$KERNEL" != "Darwin" ] ; then
    ! $PRINT_ONLY && echo "Only supports Linux and Darwin kernels, Kernel: $KERNEL" 1>&2
    HAS_ERROR=true
fi

if [ "$CPU" != "x86_64" ] && [ "$CPU" != "arm64" ] ; then
    ! $PRINT_ONLY && echo "Only supports x86_64 and arm64 cpus, Cpu: $CPU" 1>&2
    HAS_ERROR=true
fi

if [ "$VENDOR" = "" ] ; then
    ! $PRINT_ONLY && echo "Failed to detector Vendor and it was not supplied" 1>&2
    HAS_ERROR=true
fi

if [ "$URLS" = "" ] ; then
    ! $PRINT_ONLY && echo "No URLs were supplied" 1>&2
    HAS_ERROR=true
fi

if [ "$MANIFEST" = "" ] ; then
    ! $PRINT_ONLY && echo "The manifest file was not supplied" 1>&2
    HAS_ERROR=true
elif [ ! -f "$MANIFEST" ] ; then
    ! $PRINT_ONLY && echo "File not found, manifest file: '$MANIFEST'" 1>&2
    HAS_ERROR=true
fi

if [ "$SELECT_TOOLCHAIN" = "" ] ; then
    ! $PRINT_ONLY && echo "No toolchain was selected" 1>&2
    HAS_ERROR=true
fi

if $HAS_ERROR && ! $PRINT_ONLY ; then
    echo "Aborting..." 1>&2
    exit 1
fi

ARCHIVE_LINE="$(archive_line)"
if [ "$ARCHIVE_LINE" = "" ] ; then
    ! $PRINT_ONLY && echo "Failed to find toolchain archive, toolchain: $SELECT_TOOLCHAIN, kernel: $KERNEL, cpu: $CPU, vendor: $VENDOR" 1>&2
    ! $PRINT_ONLY && exit 1
fi

HASHSUM="$(echo "$ARCHIVE_LINE" | awk '{ print $1 }')"   
ARCHIVE="$(echo "$ARCHIVE_LINE" | awk '{ print $2 }')"

# ------------------------------------------------------------------------------------------- action

if $PRINT_ONLY ; then
    cat <<EOF
QUIET            $($QUIET && echo "true" || echo "false")
DOWNLOAD_CACHE   $DOWNLOAD_DIR
INSTALL_PREFIX   $INSTALL_PREFIX
SELECT_TOOLCHAIN $SELECT_TOOLCHAIN
CPU              $CPU
VENDOR           $VENDOR
MANIFEST         $MANIFEST $([ ! -f "$MANIFEST" ] && echo -n "(Not found)")
ARCHIVE          $ARCHIVE
HASHSUM          $HASHSUM
PRINT_ONLY       $($PRINT_ONLY && echo "true" || echo "false")

URLs to attempt to download, in order: $([ "$URLS" = "" ] && echo "(No URLs specified)" || true)
EOF
    for URL in $URLS ; do
        echo "   $URL/$ARCHIVE"
    done
    echo
    exit 0
fi

install_toolchain "$ARCHIVE" "$HASHSUM"

