"""
Module to run clang-format.
"""

load(":common.bzl", "collect_cc_dependencies")

# -- Runs clang-format

def file_is_filtered(ctx, file):
    """Returns TRUE if, and only it, the passed file should be filtered according to ctx's filters

    Args:
      ctx: The context with `ctx.attr.filter_files`
      file: The file whose name (path) will be tested against the filters

    Returns:
      True or False
    """
    if ctx.attr.filter_files:
        for pattern in ctx.attr.filter_files:
            if file.path.startswith(pattern):
                return True
    return False

def _clang_format_check_impl(ctx):
    is_check_only = (ctx.attr.mode == "check")
    extension = ".format-check" if is_check_only else ".format-fix"

    # By default, use `clang-format` on PATH
    tools = []
    if ctx.attr.clang_format:
        tools.append(ctx.executable.clang_format)
    exe = ctx.executable.clang_format.path if ctx.attr.clang_format else "clang-format"

    # Collect the inputs, removing duplicates
    unique_inputs = {
        file: True
        for target in ctx.attr.targets
        for file in target[OutputGroupInfo]._collected_cc_deps.to_list()
    }

    # Apply further filters
    inputs = [file for file, _ in unique_inputs.items() if not file_is_filtered(ctx, file)]

    copyright = ctx.attr.copyright_check if ctx.attr.copyright_check else ""
    outfiles = []
    for file in inputs:
        outfile = ctx.actions.declare_file(file.path + extension)
        outfiles.append(outfile)

        args = ctx.actions.args()
        args.add("True" if is_check_only == True else "False")
        args.add(file.path)
        args.add(copyright)
        args.add(outfile.path)

        command = """
#!/bin/bash

set -euo pipefail

CHECK_ONLY="$1"
FILENAME="$2"
COPYRIGHT="$3"        
OUTFILE="$4"

rm -f "$OUTFILE"
        
check_file_for_copyright()
{{
    head -n 20 "$FILENAME" | grep -i "copyright" | grep -i "$COPYRIGHT" | grep -iq "all rights reserved" && return 0 || true
    echo "The file '$FILENAME' is missing a copyright notice like:"
    echo ""
    echo "   copyright $COPYRIGHT (yyyy) all rights reserved"
    echo ""
    exit 1
}}

if [ "$COPYRIGHT" != "" ] ; then
    check_file_for_copyright
fi

if [ "$CHECK_ONLY" = "False" ] ; then
   {0} -i "$FILENAME"
fi

{0} -n -Werror "$FILENAME" && touch "$OUTFILE" && exit 0
exit 1
""".format(exe)

        inputs = [file]
        if ctx.attr.config_file:
            inputs += ctx.attr.config_file.files.to_list()

        ctx.actions.run_shell(
            mnemonic = "ClangFormat",
            inputs = inputs,
            outputs = [outfile],
            command = command,
            arguments = [args],
            tools = tools,
        )

    return [DefaultInfo(files = depset(outfiles))]

clang_format_internal = rule(
    implementation = _clang_format_check_impl,
    attrs = {
        "targets": attr.label_list(aspects = [collect_cc_dependencies]),
        "clang_format": attr.label(
            mandatory = False,
            executable = True,
            cfg = "exec",
        ),
        "config_file": attr.label(mandatory = False),
        "copyright_check": attr.string(mandatory = False),
        "mode": attr.string(values = ["check", "fix"], mandatory = True),
        "filter_files": attr.string_list(mandatory = False),
    },
)
