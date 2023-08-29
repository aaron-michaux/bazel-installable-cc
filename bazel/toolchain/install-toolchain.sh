#!/bin/bash

set -eo pipefail

QUIET=false
CACHE_ROOT="$HOME/.cache/bazel"
DOWNLOAD_ROOT="$CACHE_ROOT/downloads"
TOOLCHAIN_ROOT="$CACHE_ROOT/toolchain"

# Support linux/darwin, x86_64/arm64
KERNEL="$(uname -s)"
CPU="$(uname -m)"

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
            
   Examples:

      # Install the llvm-16 toolchain
      > $EXEC llvm-16

      # Install the llvm-15.0.6
      > $EXEC llvm-15.0.6

      # gcc12.2
      > $EXEC gcc-12.2

EOF
}

# ------------------------------------------------------------------------------------ llvm_archives

llvm_archives()
{
    cat <<EOF
# 12.0.0                                                   
clang+llvm-12.0.0-aarch64-linux-gnu.tar.xz                d05f0b04fb248ce1e7a61fcd2087e6be8bc4b06b2cc348792f383abf414dec48
clang+llvm-12.0.0-x86_64-apple-darwin.tar.xz              7bc2259bf75c003f644882460fc8e844ddb23b27236fe43a2787870a4cd8ab50
clang+llvm-12.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz    9694f4df031c614dbe59b8431f94c68631971ad44173eecc1ea1a9e8ee27b2a3
clang+llvm-12.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz    a9ff205eb0b73ca7c86afc6432eed1c2d49133bd0d49e47b15be59bbf0dd292e
                                                          
# 12.0.1                                                   
clang+llvm-12.0.1-aarch64-linux-gnu.tar.xz                3d4ad804b7c85007686548cbc917ab067bf17eaedeab43d9eb83d3a683d8e9d4
clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz    6b3cc55d3ef413be79785c4dc02828ab3bd6b887872b143e3091692fc6acefe7
                                                          
# 13.0.0                                                   
clang+llvm-13.0.0-x86_64-apple-darwin.tar.xz              d051234eca1db1f5e4bc08c64937c879c7098900f7a0370f3ceb7544816a8b09
clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz    76d0bf002ede7a893f69d9ad2c4e101d15a8f4186fbfe24e74856c8449acd7c1
clang+llvm-13.0.0-x86_64-linux-gnu-ubuntu-20.04.tar.xz    2c2fb857af97f41a5032e9ecadf7f78d3eff389a5cd3c9ec620d24f134ceb3c8
                                                          
# 13.0.1                                                   
clang+llvm-13.0.1-aarch64-linux-gnu.tar.xz                15ff2db12683e69e552b6668f7ca49edaa01ce32cb1cbc8f8ed2e887ab291069
clang+llvm-13.0.1-x86_64-apple-darwin.tar.xz              dec02d17698514d0fc7ace8869c38937851c542b02adf102c4e898f027145a4d
clang+llvm-13.0.1-x86_64-linux-gnu-ubuntu-18.04.tar.xz    84a54c69781ad90615d1b0276a83ff87daaeded99fbc64457c350679df7b4ff0
                                                          
# 14.0.0                                                   
clang+llvm-14.0.0-aarch64-linux-gnu.tar.xz                1792badcd44066c79148ffeb1746058422cc9d838462be07e3cb19a4b724a1ee
clang+llvm-14.0.0-x86_64-apple-darwin.tar.xz              cf5af0f32d78dcf4413ef6966abbfd5b1445fe80bba57f2ff8a08f77e672b9b3
clang+llvm-14.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz    61582215dafafb7b576ea30cc136be92c877ba1f1c31ddbbd372d6d65622fef5
                                                          
# 15.0.0                                                   
clang+llvm-15.0.0-aarch64-linux-gnu.tar.xz                527ed550784681f95ec7a1be8fbf5a24bd03d7da9bf31afb6523996f45670be3
clang+llvm-15.0.0-arm64-apple-darwin21.0.tar.xz           cfd5c3fa07d7fccea0687f5b4498329a6172b7a15bbc45b547d0ac86bd3452a5
clang+llvm-15.0.0-x86_64-apple-darwin.tar.xz              8fb11e6ada98b901398b2e7b0378a3a59e88c88c754e95d8f6b54613254d7d65
                                                          
# 15.0.6                                                   
clang+llvm-15.0.6-aarch64-linux-gnu.tar.xz                8ca4d68cf103da8331ca3f35fe23d940c1b78fb7f0d4763c1c059e352f5d1bec
clang+llvm-15.0.6-arm64-apple-darwin21.0.tar.xz           32bc7b8eee3d98f72dd4e5651e6da990274ee2d28c5c19a7d8237eb817ce8d91
clang+llvm-15.0.6-x86_64-linux-gnu-ubuntu-18.04.tar.xz    38bc7f5563642e73e69ac5626724e206d6d539fbef653541b34cae0ba9c3f036
                                                          
# 15.0.7                                                   
clang+llvm-15.0.7-arm64-apple-darwin22.0.tar.xz           867c6afd41158c132ef05a8f1ddaecf476a26b91c85def8e124414f9a9ba188d
clang+llvm-15.0.7-x86_64-apple-darwin21.0.tar.xz          d16b6d536364c5bec6583d12dd7e6cf841b9f508c4430d9ee886726bd9983f1c
                                                          
# 16.0.0                                                   
clang+llvm-16.0.0-aarch64-linux-gnu.tar.xz                b750ba3120e6153fc5b316092f19b52cf3eb64e19e5f44bd1b962cb54a20cf0a
clang+llvm-16.0.0-arm64-apple-darwin22.0.tar.xz           2041587b90626a4a87f0de14a5842c14c6c3374f42c8ed12726ef017416409d9
clang+llvm-16.0.0-x86_64-linux-gnu-ubuntu-18.04.tar.xz    2b8a69798e8dddeb57a186ecac217a35ea45607cb2b3cf30014431cff4340ad1
                                                          
# 16.0.1                                                   
clang+llvm-16.0.1-aarch64-linux-gnu.tar.xz                83e38451772120b016432687c0a3aab391808442b86f54966ef44c73a26280ac
clang+llvm-16.0.1-arm64-apple-darwin22.0.tar.xz           cb487fa991f047dc79ae36430cbb9ef14621c1262075373955b1d97215c75879
                                                          
# 16.0.2                                                   
clang+llvm-16.0.2-aarch64-linux-gnu.tar.xz                de89d138cfb17e2d81fdaca2f9c5e0c042014beea6bcacde7f27db40b69c0bdc
clang+llvm-16.0.2-arm64-apple-darwin22.0.tar.xz           539861297b8aa6be8e89bf68268b07d79d7a1fde87f4b98f123709f13933f326
clang+llvm-16.0.2-x86_64-linux-gnu-ubuntu-22.04.tar.xz    9530eccdffedb9761f23cbd915cf95d861b1d95f340ea36ded68bd6312af912e
                                                          
# 16.0.3                                                   
clang+llvm-16.0.3-aarch64-linux-gnu.tar.xz                315fd821ddb3e4b10c4dfabe7f200d1d17902b6a5ccd5dd665a0cd454bca379f
clang+llvm-16.0.3-arm64-apple-darwin22.0.tar.xz           b9068eee1cf1e17848241ea581a2abe6cb4a15d470ec515c100f8b52e4c6a7cb
clang+llvm-16.0.3-x86_64-linux-gnu-ubuntu-22.04.tar.xz    638d32fd0032f99bafaab3bae63a406adb771825a02b6b7da119ee7e71af26c6
                                                              
# 16.0.4                                                   
clang+llvm-16.0.4-arm64-apple-darwin22.0.tar.xz           429b8061d620108fee636313df55a0602ea0d14458c6d3873989e6b130a074bd
EOF
}

# ------------------------------------------------------------------------------------- gcc_archives

gcc_archives()
{
    cat <<EOF
gcc-12.2.0--x86_64--linux.tar.xz   123
EOF
}

# --------------------------------------------------------------------------------------------- llvm

lookup_llvm_archive()
{
    local VERSION="$1"
    # TODO, distribution: rhel, sles, ubuntu, doh!
    local ARCHIVE_LINE="$(llvm_archives | grep "clang+llvm-${VERSION}" | grep -i "$KERNEL" | grep -i "$CPU" | tail -n 1)"
    if [ "$ARCHIVE_LINE" = "" ] ; then
        echo "failed to find LLVM archive, version: $VERSION, kernel: $KERNEL, cpu: $CPU" 1>&2
        exit 1
    fi
    local ARCHIVE="$(echo "$ARCHIVE_LINE" | awk '{ print $1 }')"
    local HASHSUM="$(echo "$ARCHIVE_LINE" | awk '{ print $2 }')"
    local URL_BASE="https://github.com/llvm/llvm-project/releases/download/llvmorg-"
    local ARCHIVE_VERSION="$(echo "$ARCHIVE" | awk -F- '{ print $2 }')"
    local INSTALL_DIR="llvm-$ARCHIVE_VERSION"
    echo "$INSTALL_DIR ${URL_BASE}${ARCHIVE_VERSION}/${ARCHIVE} ${HASHSUM}"
}

# ---------------------------------------------------------------------------------------------- gcc

lookup_gcc_archive()
{
    local VERSION="$1"
    local KERNEL="$(uname -s)"
    local CPU="$(uname -m)"

    local ARCHIVE_LINE="$(gcc_archives | grep -E "^${VERSION}" | grep -i "$KERNEL" | grep -i "$CPU" | tail -n 1)"
    if [ "$ARCHIVE_LINE" = "" ] ; then
        echo "failed to find gcc archive, version: $VERSION, kernel: $KERNEL, cpu: $CPU" 1>&2
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

install_llvm()
{
    local LINE="$(lookup_llvm_archive "$VERSION")"
    local TOOLCHAIN="$(echo "$LINE" | awk '{ print $1}')"
    local URL="$(echo "$LINE" | awk '{ print $2}')"
    local EXPECTED_HASH="$(echo "$LINE" | awk '{ print $3}')"
    install_toolchain "$TOOLCHAIN" "$URL" "$EXPECTED_HASH"
}

install_gcc()
{
    local LINE="$(lookup_gcc_archive "$VERSION")"
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
    [ "$ARG" = "-p" ] || [ "$ARG" = "--prefix" ] && TOOLCHAIN_ROOT="$1" && shift && continue
    [ "$ARG" = "-d" ] || [ "$ARG" = "--download-dir" ] && DOWNLOAD_ROOT="$1" && shift && continue
    if [ "$SELECT_TOOLCHAIN" != "" ] ; then
        echo "unexpected argument: '$ARG', aborting" 1>&2 && exit 1
    fi
    SELECT_TOOLCHAIN="$ARG"
done

if [ "$KERNEL" != "Linux" ] && [ "$KERNEL" != "Darwin" ] ; then
    echo "only supports Linux and Darwin kernels" 1>&2 && exit 1
fi

if [ "$CPU" != "x86_64" ] && [ "$CPU" != "arm64" ] ; then
    echo "only supports x86_64 and arm64 cpus" 1>&2 && exit 1
fi

if [ "$SELECT_TOOLCHAIN" = "" ] ; then
    echo "no toolchain was selected, aborting" 1>&2 && exit 1
fi

IS_GCC=false
IS_LLVM=false
VERSION=""
if [ "${SELECT_TOOLCHAIN:0:4}" = "gcc-" ] ; then
    IS_GCC=true
    VERSION="${SELECT_TOOLCHAIN:4}"
elif [ "${SELECT_TOOLCHAIN:0:5}" = "llvm-" ] ; then
    IS_LLVM=true
    VERSION="${SELECT_TOOLCHAIN:5}"
elif [ "${SELECT_TOOLCHAIN:0:6}" = "clang-" ] ; then
    IS_LLVM=true
    VERSION="${SELECT_TOOLCHAIN:6}"
else
    echo "toolchain must start with 'gcc-' or 'llvm-', got '$SELECT_TOOLCHAIN', aborting" 1>&2 && exit 1
fi

if [ "$VERSION" = "" ] ; then
    echo "failed to extract version for toolchain, aborting" 1>&2 && exit 1
fi


# ------------------------------------------------------------------------------------------- action

if $IS_LLVM ; then
    install_llvm "$VERSION"
elif $IS_GCC ; then
    install_gcc "$VERSION"
fi

