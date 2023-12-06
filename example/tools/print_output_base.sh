#!/bin/bash

set -euo pipefail

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
WORKSPACE_DIR="$(cd "$(dirname "$THIS_SCRIPT")/.." ; pwd -P)"

HASH="$(echo "$WORKSPACE_DIR" | md5sum | awk '{ print $1 }')"
OUTBASE="$HOME/.cache/bazel/_${HASH}"
echo "$OUTBASE"
