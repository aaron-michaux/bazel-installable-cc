#!/bin/bash

show_help()
{
    cat <<EOF

   Usage: $(basename $0) <variable> [queries...]*

      Bazel provides no way to use a wildcard as a dependency:

         myrule(name = "example", deps = "//source/...") # <-- forbidden

      Yet this is probably what you want to do for selecting targets for 
      clang-tidy, clang-format, and refresh_compile_commands.

      Bazel makes it impossible to create an "in-process" work-around.
      For example, a `genquery` rule cannot have a wildcard, and furthermore,
      it's impossible to run `bazel query` inside of a repository_rule:
      bazel will hang!

   Examples:

      # Generate skylark for SOURCE_TARGETS = ["//source/:foo", ...]
      > $(basename $0) SOURCE_TARGETS //source/... 
   
      # Query multiple targets
      > $(basename $0) SRC_INC_TARGETS //source/... //include...

EOF
}

# -- Parse the command line

for ARG in "$@" ; do
    [ "$ARG" = "-h" ] || [ "$ARG" = "--help" ] && show_help && exit 0
done

if (( $# == 0 )) ; then
    echo "Expected at least a variable name, pass -h for help" 1>&2 && exit 1
fi

VARIABLE="$1"
shift

TMPD="$(mktemp -d /tmp/$(basename "$0").XXXXXX)"
trap cleanup EXIT
cleanup()
{
    rm -rf "$TMPD"
}

query_targets()
{
    for QUERY in "$@" ; do
        if ! bazel query "$QUERY" 2>"$TMPD/stderr" ; then
            echo "ERROR executing query:" 1>&2
            echo 1>&2
            echo "   bazel query $QUERY" 1>&2
            echo 1>&2
            cat "$TMPD/stderr" 1>&2
            exit 1
        fi
    done | sort | uniq 
}

target_list()
{
    query_targets "$@" | sed 's,^, ",' | sed 's,$,",' | tr '\n' ',' | sed 's/,$//' | sed 's,^ *,,'
}

print_as_string_list()
{
    printf "%s = [%s]\n" "$VARIABLE" "$(target_list "$@")"
}

print_as_string_list "$@"
