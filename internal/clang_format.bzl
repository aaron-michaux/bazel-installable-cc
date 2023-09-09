"""
Module to run clang-format.
"""

load(":common.bzl", "collect_cc_dependencies")

# -- Runs clang-format

def file_is_filtered(ctx, file):
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
    
    outfiles = []
    for file in inputs:
        outfile = ctx.actions.declare_file(file.path + extension)
        outfiles.append(outfile)

        args = ctx.actions.args()
        args.add("True" if is_check_only == True else "False")
        args.add(file.path)
        args.add(outfile.path)

        command = """
set -euo pipefail
CHECK_ONLY="$1"
FILENAME="$2"
OUTFILE="$3"
rm -f "$OUTFILE"
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
        "mode": attr.string(values = ["check", "fix"], mandatory = True),
        "filter_files": attr.string_list(mandatory = False),
    },
)
