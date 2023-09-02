#!/bin/bash

set -e

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"
source "$SCRIPT_DIR/platform.sh"

# ------------------------------------------------------------------------- Help

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <tool>

   Options:

      --install-dependencies  Instead of building, install build dependencies

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

# ------------------------------------------------------ Host Platform Variables

TOOLS_DIR="$TOOLCHAINS_DIR/tools"
HOST_CC="/usr/bin/gcc"
HOST_CXX="/usr/bin/g++"
CMAKE="$TOOLS_DIR/bin/cmake"

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
        echo "Directory '$D' is not writable by $USER, chgrp..."
        test_add_group "$D" "staff" "adm" "$USER" 
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
    
    # TODO: use a fresh docker container to figure our the minimal list
    if [ "$VENDOR" = "ubuntu" ] || [ "$VENDOR" = "debian" ] ; then
        export DEBIAN_FRONTEND=noninteractive
        # TODO: test for 'sudo', if ignore this line if it doesn't exist
        sudo apt-get install -y -qq \
             wget subversion automake swig python2.7-dev libedit-dev libncurses5-dev  \
             gcc-multilib python3-dev python3-pip python3-tk python3-lxml python3-six \
             libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
             libgmp-dev libmpfr-dev libmpc-dev patchelf liblz-dev pax-utils bison flex \
             libxapian-dev

    elif [ "$VENDOR" = "oracle" ] ; then
        sudo yum install -y bison xapian-core-devel
    fi
}

# ------------------------------------------------------------------------ build

build_cmake()
{
    local VERSION="$1"
    local FILE_BASE="cmake-$VERSION"
    local FILE="$FILE_BASE.tar.gz"

    cd "$TMPD"
    wget "https://github.com/Kitware/CMake/archive/refs/tags/$VERSION.tar.gz"
    cat "$VERSION.tar.gz" | gzip -dc | tar -xf -

    cd "CMake-${VERSION:1}"
    nice ./configure --prefix="$TOOLS_DIR"
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
    if [ ! -x "$CMAKE" ] || [ "$FORCE" = "True" ] ; then
        build_cmake v3.25.1
    fi
    
    local SRC_D="$TMPD/$LLVM_DIR"
    local BUILD_D="$TMPD/build-llvm-${VERSION}"
    
    rm -rf "$BUILD_D"
    mkdir -p "$SRC_D"
    mkdir -p "$BUILD_D"

    cd "$SRC_D"

    if [ ! -d "llvm-project" ] ; then
        git clone https://github.com/llvm/llvm-project.git
    fi
    cd llvm-project
    git checkout main
    git pull origin main
    git checkout "llvmorg-${VERSION}"

    # local EXTRA_LLVM_DEFINES=""
    # local MAJOR_VERSION="$(echo "$VERSION" | awk -F. '{ print $1 }')"
    # if (( $MAJOR_VERSION <= 12 )) ; then
    #     EXTRA_LLVM_DEFINES="-D COMPILER_RT_BUILD_GWP_ASAN=Off -D COMPILER_RT_BUILD_LIBFUZZER=Off -D COMPILER_RT_BUILD_ORC=Off -D COMPILER_RT_BUILD_SANITIZERS=OFF"
    #     #-DBacktrace_INCLUDE_DIR=$INSTALL_PREFIX/include -DBacktrace_LIBRARY=$INSTALL_PREFIX/lib/libexecinfo.so
    # fi
    
    cd "$BUILD_D"
    
    nice $CMAKE -G "Unix Makefiles" \
         -D LLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld" \
         -D LLVM_ENABLE_RUNTIMES="compiler-rt;libc;libcxx;libcxxabi;libunwind" \
         -D CMAKE_BUILD_TYPE=Release \
         -D CMAKE_C_COMPILER=$HOST_CC \
         -D CMAKE_CXX_COMPILER=$HOST_CXX \
         -D LLVM_ENABLE_ASSERTIONS=Off \
         -D LIBCXX_ENABLE_STATIC_ABI_LIBRARY=Yes \
         -D LIBCXX_ENABLE_SHARED=YES \
         -D LIBCXX_ENABLE_STATIC=YES \
         -D LLVM_BUILD_LLVM_DYLIB=YES \
         -D LLVM_LIBC_ENABLE_LINTING=Off \
         -D LLVM_USE_LINKER=lld \
         -D COMPILER_RT_ENABLE_IOS:BOOL=Off \
         $EXTRA_LLVM_DEFINES \
         -D CMAKE_INSTALL_PREFIX:PATH="$INSTALL_PREFIX" \
         $SRC_D/llvm-project/llvm

    nice make -j$(nproc) 2>$BUILD_D/stderr.text | tee $BUILD_D/stdout.text
    nice make install 2>>$BUILD_D/stderr.text | tee -a $BUILD_D/stdout.text
    cat $BUILD_D/stderr.text   
}

# -------------------------------------------------------------------------- gcc

build_gcc()
{
    local INSTALL_PREFIX="$1"
    local VERSION="$2"
    
    local MAJOR_VERSION="$(echo "$VERSION" | sed 's,\..*$,,')"
    local SRCD="$TMPD/$SUFFIX"
    
    mkdir -p "$SRCD"
    cd "$SRCD"
    if [ ! -d "gcc" ] ;then
        git clone https://github.com/gcc-mirror/gcc.git
    fi
    
    cd gcc
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
         --disable-nls
    
    nice make -j$(nproc) 2>$SRCD/build/stderr.text | tee $SRCD/build/stdout.text
    nice make install | tee -a $SRCD/build/stdout.text
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

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "--cleanup" ]       && export CLEANUP="True" && continue
    [ "$ARG" = "--no-cleanup" ]    && export CLEANUP="False" && continue
    [ "$ARG" = "--force" ] || [ "$ARG" = "-f" ] && export FORCE_INSTALL="True" && continue
    [ "$ARG" = "--install-dependencies" ] && INSTALL_DEPS = "True" && continue
    [ "$ARG" = "--toolchain-root" ] && export TOOLCHAINS_DIR="$1" && shift && continue
    
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
      
if [ "$INSTALL_DEPS" = "True" ] ; then
    install_dependences
fi

if [ "$COMPILER" = "" ] ; then
    echo "Must specify a compiler to build!" 1>&2 && exit 1
fi

SCRIPT_NAME="$(basename "$THIS_SCRIPT")"
if [ "$CLEANUP" = "True" ] ; then
    TMPD="$(mktemp -d /tmp/$(basename "$SCRIPT_NAME" .sh).XXXXXX)"
else
    TMPD="/tmp/$(basename "$SCRIPT_NAME" .sh)-${USER}"
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
INSTALL_PREFIX="${TOOLCHAINS_DIR}/${COMPILER}-${VERSION}--${MACHINE}--${VENDOR_TAG}--${PLATFORM}"
if [ "$FORCE_INSTALL" = "True" ] || [ ! -x "$INSTALL_PREFIX/bin/$EXEC" ] ; then
    ensure_directory "$TOOLCHAINS_DIR"
    build_$COMPILER "$INSTALL_PREFIX" $VERSION
else
    echo "Skipping installation, executable found: '$EXEC'"
fi

