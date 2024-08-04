#!/bin/bash

set -eu

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"
source "$SCRIPT_DIR/platform.sh"

# ------------------------------------------------------------------------- Help

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <tool>

   Options:

      --install-dependencies  Install build dependencies before building

      --cleanup               Remove temporary files after building
      --no-cleanup            Do not remove temporary files after building
      --force                 Force reinstall of target
      --toolchain-root        Overwrite default toolchain directory '$TOOLCHAINS_DIR'

     

   Tool:

      gcc-x.y.z
      llvm-x.y.z

   Examples:

      # Install build dependencies; requires sudo or root
      > $(basename $0) --install-dependencies

      # Install gcc version 13.1.0 to $TOOLCHAINS_DIR
      > $(basename $0) gcc-13.1.0

      # Install llvm version 16.0.2 to $TOOLCHAINS_DIR
      > $(basename $0) llvm-16.0.2

   Repos:

      https://github.com/gcc-mirror/gcc
      https://github.com/llvm/llvm-project

EOF
}

# ---------------------------------------------------------- Check Compatibility

# In compatibility Chart
# +-----------------------+-------+-------+
# | Host                  | LLVM  |  GCC  |
# +-----------------------+-------+-------+
# | Debian Trixie (gcc13) | 12-14 |   9   |
# | Ubuntu 24.04  (gcc13) | 12-13 |   9   |
# | Ubuntu 22.04  (gcc11) |   -   |   -   |
# | Ubuntu 20.04   (gcc9) |   -   |   -   |
# | OL 8.9         (gcc8) |   -   |   -   |
# | OL 8.10        (gcc8) |   -   |   -   |
# +-----------------------+-------+-------+
#
# gcc9      incompatible with newer glibc
# llvm12-14 incompatible with python 3.12 or newer, because distutils 

check_compatibility()
{
    local VENDOR_TAG="$1"
    local COMPILER="$2"
    local VERSION="$3"

    local MAJOR_VERSION="$(echo "$VERSION" | awk -F. '{ print $1 }')"
    
    if [ "$VENDOR_TAG" = "debian-trixie" ] ; then
        [ "$COMPILER" = "gcc" ]  && (( $MAJOR_VERSION >= 10 )) && return 0
        [ "$COMPILER" = "llvm" ] && (( $MAJOR_VERSION >= 15 )) && return 0
    fi

    if [ "$VENDOR_TAG" = "ubuntu-noble" ] ; then
        [ "$COMPILER" = "gcc" ]  && (( $MAJOR_VERSION >= 10 )) && return 0
        [ "$COMPILER" = "llvm" ] && (( $MAJOR_VERSION >= 14 )) && return 0
    fi

    if [ "$VENDOR_TAG" = "ubuntu-jammy" ] ; then
        [ "$COMPILER" = "gcc" ]  && (( $MAJOR_VERSION >=  9 )) && return 0
        [ "$COMPILER" = "llvm" ] && (( $MAJOR_VERSION >= 12 )) && return 0
    fi

    if [ "$VENDOR_TAG" = "ubuntu-focal" ] ; then
        [ "$COMPILER" = "gcc" ]  && (( $MAJOR_VERSION >=  9 )) && return 0
        [ "$COMPILER" = "llvm" ] && (( $MAJOR_VERSION >= 12 )) && return 0
    fi

    if [ "$VENDOR_TAG" = "ol-8.10" ] ; then
        [ "$COMPILER" = "gcc" ]  && (( $MAJOR_VERSION >=  9 )) && return 0
        [ "$COMPILER" = "llvm" ] && (( $MAJOR_VERSION >= 12 )) && return 0
    fi

    if [ "$VENDOR_TAG" = "ol-8.9" ] ; then
        [ "$COMPILER" = "gcc" ]  && (( $MAJOR_VERSION >=  9 )) && return 0
        [ "$COMPILER" = "llvm" ] && (( $MAJOR_VERSION >= 12 )) && return 0
    fi

    return 1
}

# ------------------------------------------------------ Host Platform Variables

HOST_CC="/usr/bin/gcc"
HOST_CXX="/usr/bin/g++"
CMAKE_VERSION="v3.30.1"

# ------------------------------------------------------------- helper functions

major_version()
{
    echo "$1" | cut -d - -f 2 - | cut -d . -f 1
}

is_group()
{
    local GROUP="$1"
    cat /etc/group | grep -qE "^${GROUP}:" && return 0 || return 1
}

test_add_group()
{
    local DIR="$1"
    shift    
    for GROUP in "$@" ; do
        if is_group "$GROUP" ; then
            chgrp -R "$GROUP" "$DIR"
            return 0
        fi
    done
    return 1
}

ensure_directory()
{
    local D="$1"
    if [ ! -d "$D" ] ; then
        echo "Directory '$D' does not exist, creating..."
        mkdir -p "$D"
    fi
    if [ ! -w "$D" ] ; then
        echo "Directory '$D' is not writable by $PLATFORM_USER, chgrp..."
        test_add_group "$D" "staff" "adm" "$PLATFORM_USER" 
        chmod 775 "$D"
    fi
    if [ ! -d "$D" ] || [ ! -w "$D" ] ; then
        echo "Failed to ensure writable directory '$D', should you run as root?"
        exit 1
    fi
}

# --------------------------------------------------------- install_dependencies

install_dependences()
{
    echo "Installing build dependencies"
    
    # Don't attempt to use SUDO if it is not installed
    SUDO="$(which sudo 2>/dev/null || echo "")"
    if [ "$EUID" -ne "0" ] && [ "$SUDO" = "" ] ; then
        echo "Either 'sudo' must be installed, or must run as root" 1>&2
        exit 1
    fi
    (( $(id -u) == 0 )) && SUDO_CMD= || SUDO_CMD=sudo

    if [ "$VENDOR" = "ubuntu" ] || [ "$VENDOR" = "debian" ] ; then
        export DEBIAN_FRONTEND=noninteractive
        # TODO: test for 'sudo', if ignore this line if it doesn't exist
        $SUDO_CMD apt-get update
        $SUDO_CMD apt-get install -y -qq \
             git wget subversion automake swig python2.7-dev libedit-dev libncurses5-dev  \
             gcc-multilib python3-dev python3-pip python3-tk python3-lxml python3-six \
             libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
             libgmp-dev libmpfr-dev libmpc-dev patchelf liblz-dev pax-utils bison flex \
             libxapian-dev lld

    elif [ "$VENDOR" = "ol" ] ; then
        $SUDO_CMD yum install -y \
                  autoconf automake make gettext libtool \
                  bash expect guile git bison flex patch pkgconfig tar wget expect check zstd  \
                  mpfr-devel gmp-devel libmpc-devel zlib-devel glibc-devel libzstd-devel \
                  python3-pip python3-lxml python3-six \
                  binutils gcc gcc-c++ lld \
                  openssl-devel openssl-libs
    fi
}

# ------------------------------------------------------------------------ build

build_cmake()
{
    local VERSION="$1"
    local PREFIX="$2"
    local FILE_BASE="cmake-$VERSION"
    local FILE="$FILE_BASE.tar.gz"
    local CMAKE_BUILD_D="$TMPD/build-cmake"

    rm -rf "$CMAKE_BUILD_D"
    mkdir -p "$CMAKE_BUILD_D"
    cd "$CMAKE_BUILD_D"
    wget "https://github.com/Kitware/CMake/archive/refs/tags/$VERSION.tar.gz"
    cat "$VERSION.tar.gz" | gzip -dc | tar -xf -

    cd "CMake-${VERSION:1}"
    nice ./configure --prefix="$PREFIX"
    nice make -j$(nproc)
    nice make install
}

# ------------------------------------------------------------------------- llvm

build_llvm()
{
    local INSTALL_PREFIX="$1"
    local VERSION="$2"
    local LLVM_DIR="llvm"

    # First ensure we have a recent cmake
    if [ ! -x "$CMAKE" ] || [ "$FORCE_INSTALL" = "True" ] ; then
        CMAKE_PREFIX="$(dirname "$(dirname "$CMAKE")")"
        build_cmake "$CMAKE_VERSION" "$CMAKE_PREFIX"
    fi
    
    local SRC_D="$TMPD/$LLVM_DIR"
    local BUILD_D="$TMPD/build-llvm-${VERSION}"
    local LOGD="$TMPD/llvm-build-logs/$VERSION"

    rm -rf "$BUILD_D"
    mkdir -p "$SRC_D"
    mkdir -p "$BUILD_D"
    mkdir -p "$LOGD"

    cd "$SRC_D"

    if [ ! -d "llvm-project" ] ; then
        git clone https://github.com/llvm/llvm-project.git
    fi
    cd llvm-project
    git checkout main
    git pull origin main
    git checkout "llvmorg-${VERSION}"

    local EXTRA_LLVM_DEFINES=""
    local LLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld"
    local LLVM_ENABLE_RUNTIMES_ARG="-D LLVM_ENABLE_RUNTIMES=compiler-rt;libcxx;libcxxabi;libunwind"
    local MAJOR_VERSION="$(echo "$VERSION" | awk -F. '{ print $1 }')"
    if (( $MAJOR_VERSION <= 12 )) ; then
        LLVM_ENABLE_PROJECTS="$LLVM_ENABLE_PROJECTS;compiler-rt;libcxx;libcxxabi;libunwind;clang-tools-extra"
        LLVM_ENABLE_RUNTIMES_ARG=""
    fi
    
    cd "$BUILD_D"
    nice $CMAKE -G "Unix Makefiles" \
         -D LLVM_ENABLE_PROJECTS="$LLVM_ENABLE_PROJECTS" \
         $LLVM_ENABLE_RUNTIMES_ARG \
         -D CMAKE_BUILD_TYPE=Release \
         -D CMAKE_C_COMPILER=$HOST_CC \
         -D CMAKE_CXX_COMPILER=$HOST_CXX \
         -D LLVM_ENABLE_ASSERTIONS=Off \
         -D LIBCXX_ENABLE_STATIC_ABI_LIBRARY=Yes \
         -D LIBCXX_ENABLE_SHARED=Yes \
         -D LIBCXX_ENABLE_STATIC=Yes \
         -D LLVM_BUILD_LLVM_DYLIB=Yes \
         -D LLVM_TARGETS_TO_BUILD="X86;BPF;AArch64;ARM;WebAssembly" \
         -D CMAKE_INSTALL_PREFIX:PATH="$INSTALL_PREFIX" \
         $SRC_D/llvm-project/llvm \
         > >(tee $LOGD/stdout.text) 2> >(tee $LOGD/stderr.text >&2)

    nice make -j$(nproc) > >(tee -a $LOGD/stdout.text) 2> >(tee -a $LOGD/stderr.text >&2)
    nice make install    > >(tee -a $LOGD/stdout.text) 2> >(tee -a $LOGD/stderr.text >&2)
}

# -------------------------------------------------------------------------- gcc

build_gcc()
{
    local INSTALL_PREFIX="$1"
    local VERSION="$2"
    
    local MAJOR_VERSION="$(echo "$VERSION" | sed 's,\..*$,,')"
    local SRCD="$TMPD"
    local LOGD="$TMPD/gcc-build-logs/$VERSION"
    
    mkdir -p "$SRCD"
    mkdir -p "$LOGD"
    
    cd "$SRCD"
    if [ ! -d "gcc" ] ;then
        git clone https://github.com/gcc-mirror/gcc.git
    fi
    
    cd gcc

    # In case this file was edited by a previous run
    git checkout contrib/download_prerequisites

    # Now get the correct release
    git fetch
    git checkout releases/gcc-${VERSION}
    
    if (( $MAJOR_VERSION <= 9 )) ; then
        # some network configurations have trouble with 'ftp://' urls
        sed -i contrib/download_prerequisites -e '/base_url=/s/ftp/http/'
    fi
    contrib/download_prerequisites

    if [ -d "$SRCD/build" ] ; then rm -rf "$SRCD/build" ; fi
    mkdir -p "$SRCD/build"
    cd "$SRCD/build"    
    
    export CC=$HOST_CC
    export CXX=$HOST_CXX
    nice ../gcc/configure \
         --prefix=${INSTALL_PREFIX} \
         --enable-languages=c,c++,objc,obj-c++ \
         --disable-multilib \
         --program-suffix=-${MAJOR_VERSION} \
         --enable-checking=release \
         --with-gcc-major-version-only \
         --disable-nls \
         > >(tee $LOGD/stdout.text) 2> >(tee $LOGD/stderr.text >&2)
    
    nice make -j$(nproc) > >(tee -a $LOGD/stdout.text) 2> >(tee -a $LOGD/stderr.text >&2)
    nice make install    > >(tee -a $LOGD/stdout.text) 2> >(tee -a $LOGD/stderr.text >&2)
}

# ------------------------------------------------------------------------ parse

(( $# == 0 )) && show_help && exit 0 || true
for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

CLEANUP="True"
FORCE_INSTALL="False"
INSTALL_DEPS="False"
TMPD=""
COMPILER=""
BUILD_TMPD_BASE="/tmp/${PLATFORM_USER}-toolchains"
CHECK_ONLY="False"

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "--cleanup" ]       && export CLEANUP="True" && continue
    [ "$ARG" = "--no-cleanup" ]    && export CLEANUP="False" && continue
    [ "$ARG" = "--force" ] || [ "$ARG" = "-f" ] && export FORCE_INSTALL="True" && continue
    [ "$ARG" = "--install-dependencies" ] && INSTALL_DEPS="True" && continue
    [ "$ARG" = "--toolchain-root" ] && export TOOLCHAINS_DIR="$1" && shift && continue
    [ "$ARG" = "--build-tmp-dir" ] && BUILD_TMPD_BASE="$1" && shift && continue
    [ "$ARG" = "--base" ] && export TOOLCHAINS_DIR="$1" && BUILD_TMPD_BASE="$1" && shift && continue
    [ "$ARG" = "--check-compatibility-only" ] && CHECK_ONLY="True" && continue
    
    if [ "${ARG:0:3}" = "gcc" ] ; then
        COMPILER="gcc"
        VERSION="${ARG:4}"
        CC_MAJOR_VERSION="$(echo ${VERSION} | awk -F. '{ print $1 }')"
        EXEC="gcc-$CC_MAJOR_VERSION"        
        continue
    fi    

    if [ "${ARG:0:4}" = "llvm" ] || [ "${ARG:0:5}" = "clang" ] ; then
        [ "${ARG:0:4}" = "llvm" ]  && VERSION="${ARG:5}" || true
        [ "${ARG:0:5}" = "clang" ] && VERSION="${ARG:6}" || true
        COMPILER="llvm"
        EXEC="clang"        
        continue
    fi  

    echo "unexpected argument: '$ARG'" 1>&2 && exit 1
done

if [ "$CHECK_ONLY" = "True" ] ; then
    check_compatibility $VENDOR_TAG $COMPILER $VERSION && exit 0 || exit 1
fi

if [ "$INSTALL_DEPS" = "True" ] ; then
    install_dependences
    if [ "$COMPILER" = "" ] ; then
        exit 0 # We're done
    fi
fi

if [ "$COMPILER" = "" ] ; then
    echo "Must specify a compiler to build!" 1>&2 && exit 1
fi

FULL_NAME="${COMPILER}-${VERSION}--${MACHINE}--${VENDOR_TAG}--${PLATFORM}"
# Check compatability
if ! check_compatibility $VENDOR_TAG $COMPILER $VERSION ; then
    echo "Incompatible build, ${COMPILER}-${VERSION} does not build on ${VENDOR_TAG}"
    exit 0
fi

TOOLS_DIR="$TOOLCHAINS_DIR/tools"
CMAKE="$TOOLS_DIR/cmake/${VENDOR_TAG}--${CMAKE_VERSION}/bin/cmake"

SCRIPT_NAME="$(basename "$THIS_SCRIPT")"
if [ "$CLEANUP" = "True" ] ; then
    TMPD="$(mktemp -d /tmp/$(basename "$SCRIPT_NAME" .sh).XXXXXX)"
else
    TMPD="$BUILD_TMPD_BASE/builddir"
    mkdir -p "$TMPD"
    echo "Setting TMPD=$TMPD"
fi
trap cleanup EXIT

cleanup()
{
    if [ "$CLEANUP" = "True" ] && [ "$TMPD" != "" ] ; then
        rm -rf "$TMPD"
    fi
}

# ----------------------------------------------------------------------- action
INSTALL_PREFIX="${TOOLCHAINS_DIR}/${FULL_NAME}"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -x "$INSTALL_PREFIX/bin/$EXEC" ] ; then
    ensure_directory "$TOOLCHAINS_DIR"
    build_$COMPILER "$INSTALL_PREFIX" $VERSION
else
    echo "Skipping installation, executable found: '$EXEC'"
fi

