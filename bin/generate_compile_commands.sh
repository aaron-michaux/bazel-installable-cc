#!/bin/bash

set -euo pipefail

THIS_SCRIPT="$([ -L "$0" ] && readlink -f "$0" || echo "$0")"
SCRIPT_DIR="$(cd "$(dirname "$THIS_SCRIPT")" ; pwd -P)"
QUERY_TARGET="${SCRIPT_DIR}/query_target.sh"

# -- Variables
RULE_DIRECTORY="compiler_commands_tmp_dir"

show_help()
{
    cat <<EOF

   Usage: $(basename $0) [--config=<string>]* [queries...]*

      Generates compile_commands.json for the specified targets

   Examples:

      # Generate compiler commands for "//source/..." and "//include/..."
      > $(basename $0) //source/... //include/...

      # Apply a config before generating compiler commands
      > $(basename $0) --config=compdb //source/... //include/...

EOF
}

# -- Parse the command line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

if (( $# == 0 )) ; then
    echo "Expected at least a variable name, pass -h for help" 1>&2 && exit 1
fi

CONFIG_ARGS=""
while [[ "$1" =~ ^--config=* ]] ; do
    CONFIG_ARGS+="$1 "
    shift    
done

TARGET_LIST="$($QUERY_TARGET "$@")"

print_BUILD()
{
    cat <<EOF
load("@initialize_toolchain//:defs.bzl", "compile_commands")

TARGETS = $TARGET_LIST

compile_commands(
   name = "refresh_compile_commands",
   targets = TARGETS,
   indent = True, # Human readable, but larger output
   # NOTE: the resulting file will be: 'bazel-bin/compile_commands.json'        
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
COMMAND="bazel build --spawn_strategy=standalone ${CONFIG_ARGS}${RULE_DIRECTORY}:refresh_compile_commands"
echo
echo "   $COMMAND"
echo
$COMMAND

OUTF="bazel-bin/${RULE_DIRECTORY}/compile_commands.json"
if [ ! -f "$OUTF" ] ; then
    echo "Failed to find compilation output file: '$OUTF', aborting" 1>&2 && exit 1
fi

# Ensure that link exists and is correct
rm -f "compile_commands.json"
ln -s "$OUTF" "compile_commands.json"



