#!/bin/bash

set -euo pipefail

VERSION=2.39
INSTALL_ROOT=/opt/glibc
BUILD_ROOT="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"
CLEANUP="False"
PREFIX=""
URLS="http://localhost/downloads/third-party/glibc https://ftp.gnu.org/gnu/glibc"

# ----------------------------------------------------------------- command line

show_help()
{
    cat <<EOF

   Usage: $(basename "$0") [Options...]

      Builds and installs glibc. Assumes the following packages are installed:

         gawk bison patchelf wget

      To use the built glibc, patchelf as follows:

         patchelf --set-interpreter /path/to/glibc/install/lib/ld-linux-x86-64.so.2 \\
                  --set-rpath       /path/to/glibc/install/lib                      \\
                  /path/to/executable

   Options:

      --prefix <directory>   Install directory; default is $INSTALL_ROOT/\$VERSION
      --version <version>    The version of glibc to build; default is $VERSION

      --cleanup              Remove temporary files after building
      --no-cleanup           Do not remove temporary files after building

EOF
}

# ---------------------------------------------------------------------- cleanup

cleanup()
{
    if [ "$CLEANUP" = "True" ] ; then
        rm -rf "$TMPD"
    fi
}

make_working_dir()
{
    local SCRIPT_NAME="$(basename "$0")"

    if [ "$CLEANUP" = "True" ] ; then
        TMPD="$(mktemp -d /tmp/$(basename "$SCRIPT_NAME" .sh).XXXXXX)"
    else
        TMPD="/tmp/build-$(basename "$SCRIPT_NAME" .sh)-${USER}"
    fi
    if [ "$CLEANUP" = "False" ] ; then
        mkdir -p "$TMPD"
    fi

    trap cleanup EXIT
}

# ------------------------------------------------------- parse the command-line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

while (( $# > 0 )) ; do
    ARG="$1"
    shift

    LHS=$(echo "$ARG" | awk -F= '{ print $1 }')
    RHS=$(echo "$ARG" | awk -F= '{ print $2 }')

    [ "$ARG" = "--cleanup" ]       && export CLEANUP="True" && continue
    [ "$ARG" = "--no-cleanup" ]    && export CLEANUP="False" && continue

    [ "$LHS" = "--prefix" ]        && export INSTALL_ROOT="$RHS" && continue
    [ "$ARG" = "--prefix" ]        && export INSTALL_ROOT="$1" && shift && continue

    [ "$LHS" = "--version" ]       && export VERSION="$RHS" && continue
    [ "$ARG" = "--version" ]       && export VERSION="$1" && shift && continue

    echo "unexpected argument: '$ARG'" 1>&2 && exit 1
done

if [ "$PREFIX" = "" ] ; then
    PREFIX="$INSTALL_ROOT/$VERSION"
fi

# ----------------------------------------------------------------------- action

make_working_dir
cd "$TMPD"

SOURCE_D="glibc-${VERSION}"
BUILD_D="build"
TAR_FILE="${SOURCE_D}.tar.gz"

if [ ! -f "${TAR_FILE}" ] ; then
    for URL in $URLS ; do
        ! wget -c "${URL}/${TAR_FILE}" && continue
        break
    done
fi
if [ ! -d "$SOURCE_D" ] ; then
    tar -zxf "$TAR_FILE"
fi
rm -rf "$BUILD_D"
mkdir -p "$BUILD_D"
cd "$BUILD_D"
../${SOURCE_D}/configure --prefix=${PREFIX}
make -j                          
make install                     

