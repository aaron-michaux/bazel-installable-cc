#!/bin/bash

export TOOLCHAINS_DIR="/tmp/$([ "$USER" != "" ] && echo "${USER}-")toolchains"
export PLATFORM="$(uname -s | tr '[:upper:]' '[:lower:]')"
export MACHINE="$(uname -m)"

if [ "$PLATFORM" = "darwin" ] ; then
    echo "Use 'brew' to install toolchains on macos" 1>&2 && exit 1

elif [ -f "/etc/os-release" ] ; then
    # debian, ubuntu, ol, rhel, centos, fedora
    export VENDOR="$(cat /etc/os-release | grep -E ^ID= | awk -F= '{ print $2 }' | sed 's,",,g')"
    
    # 10, 22.04, 8.8, ...
    export VERSION="$(cat /etc/os-release | grep -E ^VERSION_ID= | awk -F= '{ print $2 }' | sed 's,",,g')"

    # bullseye, jammy, 
    export CODENAME="$(cat /etc/os-release | grep -E ^VERSION_CODENAME= | awk -F= '{ print $2 }' | sed 's,",,g')"
    if [ "$CODENAME" = "" ] ; then
        export CODENAME="$VERSION"
    fi

    export VENDOR_TAG="${VENDOR}-${CODENAME}"
    
else
    echo "Failed to determine platform" 1>&2 && exit 1
fi

