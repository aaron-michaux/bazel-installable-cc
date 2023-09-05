#!/bin/bash

set -euo pipefail

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"
QUERY_TARGET="${SCRIPT_DIR}/query_target.sh"

# -- Variables
RULE_DIRECTORY="clang_format_tmp_dir"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) --check|--fix [--config=<string>]* [queries...]*

      Runs clang-format on the specified targets

   Examples:

      # Generate compiler commands for "//source/..." and "//include/..."
      > $(basename $0) --check --config=llvm //source/... //include/...

      # Apply a config before generating compiler commands
      > $(basename $0) --fix --config=llvm //source/... //include/...

EOF
}

# -- Parse the command line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

if (( $# == 0 )) ; then
    echo "Expected at least a variable name, pass -h for help" 1>&2 && exit 1
fi

ACTION="$1"
if [ "$ACTION" != "--check" ] && [ "$ACTION" != "--fix" ] ; then
    echo "The action (1st argument) must be '--check' or '--fix', but got '$1'" 1>&2 && exit 1
fi
shift

CONFIG_ARGS=""
while (( $# > 0 )) && [[ "$1" =~ ^--config=* ]] ; do
    CONFIG_ARGS+="$1 "
    shift    
done

# The targets to run on
TARGET_LIST="$($QUERY_TARGET "$@")"

print_BUILD()
{
    cat <<EOF
load("@initialize_toolchain//:defs.bzl", "clang_format")

TARGETS = $TARGET_LIST

# -- Clang Format

alias(
    name = "clang_format_bin",
    actual = "@initialize_toolchain//:clang_format_bin",
)

clang_format(
    name = "format_check",
    mode = "check",
    clang_format = ":clang_format_bin",
    targets = TARGETS,
)

clang_format(
    name = "format_fix",
    mode = "fix",
    clang_format = ":clang_format_bin",
    targets = TARGETS,
)
EOF
}

if [ -d "${RULE_DIRECTORY}" ] ; then
    cat 1>&2 <<EOF
Directory '${RULE_DIRECTORY}' already exists; this temporary directory is
used to coax bazel into running on the correct targets. Cowardly refusing
to write over it, aborting.
EOF
    exit 1
fi

mkdir "${RULE_DIRECTORY}"
trap cleanup EXIT
cleanup()
{
    rm -rf "${RULE_DIRECTORY}"
}

print_BUILD "$@" > "${RULE_DIRECTORY}/BUILD"
RULE="$([ "$ACTION" = "--fix" ] && echo "format_fix" || echo "format_check")"
COMMAND="bazel build --spawn_strategy=standalone ${CONFIG_ARGS}${RULE_DIRECTORY}:${RULE}"
echo
echo "   $COMMAND"
echo
$COMMAND




