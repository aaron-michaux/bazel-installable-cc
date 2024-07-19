#!/bin/bash

set -euo pipefail

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"

LLVMS="llvm-18.1.8 llvm-17.0.6 llvm-16.0.6 llvm-15.0.7 llvm-14.0.6 llvm-13.0.1 llvm-12.0.1"
GCCS="gcc-14.1.0 gcc-13.3.0 gcc-12.4.0 gcc-11.4.0 gcc-10.5.0 gcc-9.5.0"

all_hosts()
{
    cat <<EOF
oraclelinux:8.9
oraclelinux:8.10
debian:trixie
ubuntu:22.04
ubuntu:24.04
EOF
}

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [build|archive] [--host HOST]? [<toolchain>|:all]

      Where toolchain can be one of:

         $LLVMS
         $GCCS

      Hosts can be:

$(all_hosts | sed 's,^,         ,')

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
    ./build-toolchain.sh $CLEANUP_ARG $INSTALL_ARG $TOOLCHAIN_ROOT_ARG --build-tmp-dir $BUILD_TMPD_BASE "$TOOL"    
}

get_dockerfile()
{
    local HOST="$1"
    echo "$HOST" | grep -q debian && echo "apt.dockerfile" && return 0 || true
    echo "$HOST" | grep -q ubuntu && echo "apt.dockerfile" && return 0 || true
    echo "$HOST" | grep -q oracle && echo "yum.dockerfile" && return 0 || true
    echo "$HOST" | grep -q fedora && echo "yum.dockerfile" && return 0 || true
    return 1
}

DO_ARCHIVE=false
DO_BUILD=false
TOOLCHAIN=""
CLEANUP_ARG="--no-cleanup"
HOSTS=
DOCKER_COMMAND_ARGS=""
INSTALL_ARG=""
BUILD_TMPD_BASE="/tmp/${USER}-toolchains"
TOOLCHAIN_ROOT_ARG=""

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

if (( $# == 0 )) ; then
    echo "Type -h for help" 1>&2 && exit 1
fi

while (( $# > 0 )) ; do
    ARG="$1"
    shift
    [ "$ARG" = "--host" ] && HOSTS+="$1 " && shift && continue

    # The rest of the args should be stored in docker-commands
    DOCKER_COMMAND_ARGS+="$ARG "
    [ "$ARG" = "build" ] && DO_BUILD=true && continue
    [ "$ARG" = "archive" ] && DO_ARCHIVE=true && continue
    [ "$ARG" = "--cleanup" ] && CLEANUP_ARG="$ARG" && continue
    [ "$ARG" = "--no-cleanup" ] && CLEANUP_ARG="$ARG" && continue
    [ "$ARG" = "--install-dependencies" ] && INSTALL_ARG="$ARG" && continue
    [ "$ARG" = "--build-tmp-dir" ] && BUILD_TMPD_BASE="$1" && DOCKER_COMMAND_ARGS+="$1 " && shift && continue
    [ "$ARG" = "--toolchain-root" ] && TOOLCHAIN_ROOT_ARG="$ARG $1" && DOCKER_COMMAND_ARGS+="$1 " && shift && continue
    [ "$ARG" = "--base" ] && TOOLCHAIN_ROOT_ARG="$ARG $1" && BUILD_TMPD_BASE="$1" && DOCKER_COMMAND_ARGS+="$1 " && shift && continue
    [ "$ARG" = ":all" ] && TOOLCHAIN="$ARG" && continue
    TOOLCHAIN+=" $ARG"
done

TOOLCHAINS=""
if [ "$TOOLCHAIN" == ":all" ] ; then
    TOOLCHAINS="$LLVMS $GCCS"
else
    # Check toolchain is in the list
    for ARG in $TOOLCHAIN ; do
        if ! echo "$LLVMS $GCCS" | grep -q "$ARG" ; then
            echo "Unexpected toolchain: '$ARG'" 1>&2
            exit 1
        fi
    done
    # Could be more than one
    TOOLCHAINS="$(echo $TOOLCHAIN)"
fi

if echo "$HOSTS" | grep -q ":all" ; then
    HOSTS="$(all_hosts | tr '\n' ' ')"
elif [ "$HOSTS" != "" ] ; then
    for HOST in $HOSTS ; do
        if ! all_hosts | grep -q "$HOST" ; then
            echo "Unexpected host: '$HOST'" 1>&2
            exit 1
        fi
    done
fi

if ! $DO_BUILD && ! $DO_ARCHIVE ; then
    echo "Must specify one of 'archive' or 'build' to actually do anything!" 1>&2
    exit 1
fi

if [ "$HOSTS" != "" ] ; then
    HAS_ERROR="false"
    TMP_USER="$([ "$(id -u)" == "0" ] && echo "root" || echo "$USER")"
    BUILD_TMPD="$BUILD_TMPD_BASE"
    mkdir -p "$BUILD_TMPD"
    for HOST in $HOSTS ; do
        DOCKER_VENDOR="$(echo "$HOST" | awk -F: '{ print $1 }')"
        DOCKER_RELEASE="$(echo "$HOST" | awk -F: '{ print $2 }')"
        DOCKER_TAG="${DOCKER_VENDOR}_${DOCKER_RELEASE}"
        docker build -f "$SCRIPT_DIR/dockerfiles/$(get_dockerfile $HOST)" \
               --build-arg VENDOR=$DOCKER_VENDOR --build-arg RELEASE=$DOCKER_RELEASE \
               -t "$DOCKER_TAG" \
               "$SCRIPT_DIR/dockerfiles"
        
        CONTAINER_NAME="$(echo "$HOST" | sed 's,:,-,')_build_container"
        docker kill "$CONTAINER_NAME" 1>/dev/null 2>/dev/null || true
        docker rm   "$CONTAINER_NAME" 1>/dev/null 2>/dev/null || true
        docker run --init --rm --name "$CONTAINER_NAME" --user $(id -u):$(id -g) -e USER=$USER -e USER_HOME=$HOME -v "$SCRIPT_DIR/..:/bazel-installable-cc" -v "$BUILD_TMPD:$BUILD_TMPD" -w "/bazel-installable-cc" ${DOCKER_TAG}:latest bin/package-toolchains.sh $DOCKER_COMMAND_ARGS || HAS_ERROR="true"
    done
    $HAS_ERROR && exit 1 || exit 0
fi

# -- If there's no toolchains and we're installing dependencies, then just do that
if [ "$TOOLCHAINS" == "" ] && [ "$INSTALL_ARG" != "" ] ; then
    ./build-toolchain.sh $CLEANUP_ARG $INSTALL_ARG
fi

# -- Build on the current host (could be recusively called within a docker container)
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



