load(":common.bzl", "collect_cc_dependencies")

# -- Runs clang-format
    
def _clang_format_check_impl(ctx):
    is_check_only = (ctx.attr.mode == "check")    
    flags = "-n -Werror" if is_check_only else "-i"
    extension = ".format-check" if is_check_only else ".format-fix"

    # By default, use `clang-format` on PATH
    tools = []
    if ctx.attr.clang_format:
        tools += [ctx.executable.clang_format]        
    exe = ctx.executable.clang_format.path if ctx.attr.clang_format else "clang-format"
        
    inputs = [file for target in ctx.attr.targets
              for file in target[OutputGroupInfo]._collected_cc_deps.to_list()] 
    outfiles = []
    for file in inputs:
        outfile = ctx.actions.declare_file(file.path + extension)
        outfiles.append(outfile)

        # command = "{} -n -Werror {} && touch {}".format(exe, file.path, outfile.path)
        # if not is_check_only:
        #     command = "{} -i {} && {}".format(exe, file.path, command)

        args = ctx.actions.args()
        args.add("True" if ctx.attr.mode == "check" else "False")
        args.add(file.path)
        args.add(outfile.path)
        
        command = """
set -euo pipefail
echo "ARGS = $*"
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
        "mode": attr.string(values = ["check", "fix"], mandatory = True)
    }
)
