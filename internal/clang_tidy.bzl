"""
For running clang-tidy
"""

load(
    ":common.bzl",
    "CcRuleSetInfo",
    "append_compiler_context_flags",
    "collect_cc_actions",
    "is_c_file",
    "is_valid_hdr_file",
)

# -- Runs clang-tidy

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

def _calc_inputs(src, config_file, compilation_context):
    return depset(
        direct = [x for x in [src, config_file] if x],
        transitive = [compilation_context.headers],
    )

def _llvm_filter_args(flag_list):
    gcc_only_flags = ["-fno-canonical-system-headers", "-fstack-usage"]
    return [x for x in flag_list if x not in gcc_only_flags]

def _gen_tidy_logic(ctx, compilation_context, label, kind, attr, srcs, cflags, cxxflags):
    # By default, use `clang-tidy` on PATH
    tools = []
    if ctx.attr.clang_tidy:
        tools.append(ctx.executable.clang_tidy)
    exe = ctx.executable.clang_tidy.path if ctx.attr.clang_tidy else "clang-tidy"

    # Get the config file (if any)
    config_file = None
    if ctx.attr.config_file:
        file_list = ctx.attr.config_file.files.to_list()
        if len(file_list) > 0:
            config_file = file_list[0]

    # All the output files to depend on
    outputs = []
    if not hasattr(attr, "srcs"):
        return outputs

    # exit early
    if ctx.attr.filter_tags:
        for tag in ctx.attr.filter_tags:
            if tag in attr.tags:
                return outputs

    for src in srcs:
        if file_is_filtered(ctx, src) or is_valid_hdr_file(src):
            continue

        outfile = ctx.actions.declare_file(src.path + ".clang-tidy")
        outputs.append(outfile)

        # Memory efficent method to build arguments
        args = ctx.actions.args()
        args.add(src.path)

        if config_file:
            args.add("--config-file={}".format(config_file.path))
        args.add("--export-fixes")
        args.add(outfile.path)

        # Now add commandline stuff that would appear in compile_commands.json
        args.add("--")

        # Add compiler generated args
        flags = cflags if is_c_file(src) else cxxflags
        args.add_all(append_compiler_context_flags(flags, compilation_context))

        command = """
filter_output()
{{
   cat - | grep -Ev '^Suppressed [0-9]* warnings' | grep -Ev '^[0-9]* warnings generated' | grep -Ev '^Use -header-filter='        
}}       
        
rm -f {1} && touch {1} && {0} "$@" 2> >(filter_output >&2)
[ -s {1} ] && exit 1 || exit 0
        """.format(exe, outfile.path)
        ctx.actions.run_shell(
            mnemonic = "ClangTidy",
            inputs = _calc_inputs(src, config_file, compilation_context),
            outputs = [outfile],
            command = command,
            arguments = [args],
            tools = tools,
        )

    return outputs

def _clang_tidy_check_impl(ctx):
    # A list of cc_rules
    cc_infos = [
        (info, t[CcInfo].compilation_context)
        for t in ctx.attr.targets
        for info in t[CcRuleSetInfo].cc_infos
    ]

    # Run on all cc_infos, skipping duplicates
    outfiles = []
    cc_dict = {}
    for cc_info, compilation_context in cc_infos:
        label = cc_info["label"]
        name = "@{}//{}:{}".format(label.workspace_name, label.package, label.name)
        if not name in cc_dict and cc_info["in_workspace"]:
            cc_dict[name] = cc_info

            # Run clang tidy on this cc_rule
            outfiles += _gen_tidy_logic(
                ctx,
                compilation_context,
                cc_info["label"],
                cc_info["kind"],
                cc_info["attr"],
                cc_info["srcs"],
                _llvm_filter_args(cc_info["cflags"]),
                _llvm_filter_args(cc_info["cxxflags"]),
            )

    return [DefaultInfo(files = depset(outfiles))]

clang_tidy_internal = rule(
    implementation = _clang_tidy_check_impl,
    attrs = {
        "targets": attr.label_list(aspects = [collect_cc_actions]),
        "clang_tidy": attr.label(
            mandatory = False,
            executable = True,
            cfg = "exec",
        ),
        "config_file": attr.label(mandatory = False),
        "compile_commands": attr.label(mandatory = False),
        "filter_files": attr.string_list(mandatory = False),
        "filter_tags": attr.string_list(mandatory = False),
    },
)
