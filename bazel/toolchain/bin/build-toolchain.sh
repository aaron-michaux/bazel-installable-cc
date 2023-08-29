#!/bin/bash

set -e

TOOLCHAINS_DIR="/opt/toolchains"

# ------------------------------------------------------------------------- Help

show_help()
{
    cat <<EOF

   Usage: $(basename $0) OPTION* <tool>

   Options:

      --cleanup              Remove temporary files after building
      --no-cleanup           Do not remove temporary files after building
      --force                Force reinstall of target

   Tool:

      gcc-x.y.z
      llvm-x.y.z

   Examples:

      # Install gcc version 13.1.0 to $TOOLCHAINS_DIR
      > $(basename $0) gcc-13.1.0

      # Install llvm version 16.0.2 to $TOOLCHAINS_DIR
      > $(basename $0) llvm-16.0.2

   Repos:

      https://github.com/gcc-mirror/gcc
      https://github.com/llvm/llvm-project

EOF
}

all_recent()
{
    cat <<EOF
# LLVM
llvm-16.0.6
llvm-15.0.7 llvm-14.0.6 llvm-13.0.1 llvm-12.0.1

# Gcc
gcc-13.2.0
gcc-12.3.0
gcc-11.4.0
gcc-10.5.0
gcc-9.5.0
EOF
}

# ------------------------------------------------------ Host Platform Variables

TOOLS_DIR="$TOOLCHAINS_DIR/tools"
HOST_CC="/usr/bin/gcc"
HOST_CXX="/usr/bin/g++"
CMAKE="$TOOLS_DIR/bin/cmake"

if [ -z ${PLATFORM+x} ] ; then
    if [ -x "/usr/bin/lsb_release" ] ; then    
        PLATFORM="ubuntu"
    elif [ -f "/etc/fedora-release" ] ; then
        PLATFORM="fedora"
    elif [ "$(uname -s)" = "Darwin" ] ; then
        PLATFORM="macos"
        LIBTOOL=glibtool
        LIBTOOLIZE=glibtoolize 
    elif [ -f /etc/os-release ] && cat /etc/os-release | grep -qi Oracle  ; then
        PLATFORM="oracle"
    fi
fi

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
            sudo chgrp -R "$GROUP" "$DIR"
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
        sudo mkdir -p "$D"
    fi
    if [ ! -w "$D" ] ; then
        echo "Directory '$D' is not writable by $USER, chgrp..."
        test_add_group "$D" "staff" "adm" "$USER" 
        sudo chmod 775 "$D"
    fi
    if [ ! -d "$D" ] || [ ! -w "$D" ] ; then
        echo "Failed to ensure writable directory '$D', should you run as root?"
        exit 1
    fi
}

# --------------------------------------------------------- install_dependencies

install_dependences()
{    
    if [ "$PLATFORM" = "ubuntu" ] ; then
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get install -y -qq \
             wget subversion automake swig python2.7-dev libedit-dev libncurses5-dev  \
             gcc-multilib python3-dev python3-pip python3-tk python3-lxml python3-six \
             libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
             libgmp-dev libmpfr-dev libmpc-dev patchelf liblz-dev pax-utils bison flex \
             libxapian-dev

    elif [ "$PLATFORM" = "oracle" ] || [ "$PLATFORM" = "fedora" ] ; then
        which bison 1>/dev/null 2>/dev/null || sudo yum install -y bison
        if [ ! -x /usr/bin/xapian-config ] ;then
           sudo yum install -y xapian-core-devel
        fi
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
    local CLANG_V="$1"
    local LLVM_DIR="llvm"

    # First ensure we have a recent cmake
    if [ ! -x "$CMAKE" ] || [ "$FORCE" = "True" ] ; then
        build_cmake v3.25.1
    fi
    
    local SRC_D="$TMPD/$LLVM_DIR"
    local BUILD_D="$TMPD/build-llvm-${CLANG_V}"
    local INSTALL_PREFIX="${TOOLCHAINS_DIR}/llvm-${CLANG_V}"
    
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
    git checkout "llvmorg-${CLANG_V}"

    # local EXTRA_LLVM_DEFINES=""
    # local MAJOR_VERSION="$(echo "$CLANG_V" | awk -F. '{ print $1 }')"
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
    local TAG="$1"
    local SUFFIX="$1"
    if [ "$2" != "" ] ; then SUFFIX="$2" ; fi
    
    local MAJOR_VERSION="$(echo "$SUFFIX" | sed 's,\..*$,,')"
    local SRCD="$TMPD/$SUFFIX"
    
    mkdir -p "$SRCD"
    cd "$SRCD"
    if [ ! -d "gcc" ] ;then
        git clone https://github.com/gcc-mirror/gcc.git
    fi
    
    cd gcc
    git fetch
    git checkout releases/gcc-${TAG}
    contrib/download_prerequisites

    if [ -d "$SRCD/build" ] ; then rm -rf "$SRCD/build" ; fi
    mkdir -p "$SRCD/build"
    cd "$SRCD/build"

    local PREFIX="${TOOLCHAINS_DIR}/gcc-${SUFFIX}"

    export CC=$HOST_CC
    export CXX=$HOST_CXX
    nice ../gcc/configure --prefix=${PREFIX} \
         --enable-languages=c,c++,objc,obj-c++ \
         --disable-multilib \
         --program-suffix=-${MAJOR_VERSION} \
         --enable-checking=release \
         --with-gcc-major-version-only
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

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "--cleanup" ]       && export CLEANUP="True" && continue
    [ "$ARG" = "--no-cleanup" ]    && export CLEANUP="False" && continue
    [ "$ARG" = "--force" ] || [ "$ARG" = "-f" ] && export FORCE_INSTALL="True" && continue

    if [ "${ARG:0:3}" = "gcc" ] ; then
        COMMAND="build_gcc ${ARG:4}"
        CC_MAJOR_VERSION="$(echo ${ARG:4} | awk -F. '{ print $1 }')"
        EXEC="$TOOLCHAINS_DIR/$ARG/bin/gcc-$CC_MAJOR_VERSION"
        continue
    fi    

    if [ "${ARG:0:4}" = "llvm" ] || [ "${ARG:0:5}" = "clang" ] ; then
        [ "${ARG:0:4}" = "llvm" ]  && VERSION="${ARG:5}" || true
        [ "${ARG:0:5}" = "clang" ] && VERSION="${ARG:6}" || true
        COMMAND="build_llvm $VERSION"
        EXEC="$TOOLCHAINS_DIR/llvm-$VERSION/bin/clang"
        continue
    fi  

    echo "unexpected argument: '$ARG'" 1>&2 && exit 1
done

if [ "$COMMAND" = "" ] ; then
    echo "Must specify a build command!" 1>&2 && exit 1
fi

SCRIPT_NAME="$(basename "$0")"
if [ "$CLEANUP" = "True" ] ; then
    TMPD="$(mktemp -d /tmp/$(basename "$SCRIPT_NAME" .sh).XXXXXX)"
else
    TMPD="/tmp/$(basename "$SCRIPT_NAME" .sh)-${USER}"
    mkdir -p "$TMPD"
fi

trap cleanup EXIT
cleanup()
{
    if [ "$CLEANUP" = "True" ] ; then
        rm -rf "$TMPD"
    fi
}

# ----------------------------------------------------------------------- action

if [ "$FORCE_INSTALL" = "True" ] || [ ! -x "$EXEC" ] ; then
    ensure_directory "$TOOLCHAINS_DIR"
    install_dependences
    $COMMAND
else
    echo "Skipping installation, executable found: '$EXEC'"
fi

