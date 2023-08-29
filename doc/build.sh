#!/bin/bash

set -e

PPWD="$(cd "$(dirname "$0")" ; pwd)"
source ../modules/shell-scripts/build-contrib/env/platform-env.sh

CONFIG_F="doxy.config"
EXEC="$TOOLS_DIR/bin/doxygen"

TMPD=$(mktemp -d /tmp/$(basename $0).XXXXX)
trap cleanup EXIT
cleanup()
{
    rm -rf $TMPD
}

# Replace PROJECT_NUMBER with git information
TAG="$(git rev-parse HEAD | head -n 1)"
COMMIT="$(git log | grep commit | head -n 1)"

cat "$PPWD/$CONFIG_F" | sed "s,<PROJECT_VERSION_NUMBER>,$TAG $COMMIT," > $TMPD/doxy-config

cd $PPWD
mkdir -p "../build/doc"
$EXEC $TMPD/doxy-config 1>/dev/null


