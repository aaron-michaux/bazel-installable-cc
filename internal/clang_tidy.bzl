load(
    ":common.bzl",
    "CcRuleInfoSet",
    "append_compiler_context_flags",
    "collect_cc_actions",
    "is_c_file",
)

# -- Runs clang-tidy

def calc_inputs(src, config_file, compilation_context):
    return depset(
        direct = [x for x in [src, config_file] if x],
        transitive = [compilation_context.headers],
    )

def llvm_filter_args(l):
    gcc_only_flags = ["-fno-canonical-system-headers", "-fstack-usage"]
    return [x for x in l if x not in gcc_only_flags]

def gen_tidy_logic(ctx, compilation_context, label, kind, attr, srcs, cflags, cxxflags):
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

    for src in srcs:
        outfile = ctx.actions.declare_file(src.path + ".clang-tidy")
        outputs.append(outfile)

        # Memory efficent method to build arguments
        args = ctx.actions.args()

        if config_file:
            args.add("--config-file={}".format(config_file.path))
        args.add("--export-fixes")
        args.add(outfile.path)
        args.add(src.path)

        # Now add commandline stuff that would appear in compile_commands.json
        args.add("--")

        # Add compiler generated args
        flags = cflags if is_c_file(src) else cxxflags
        args.add_all(append_compiler_context_flags(flags, compilation_context))

        command = """
rm -f {1} && touch {1} && {0} "$@"
[ -s {1} ] && exit 1 || exit 0
        """.format(exe, outfile.path)
        ctx.actions.run_shell(
            mnemonic = "ClangTidy",
            inputs = calc_inputs(src, config_file, compilation_context),
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
        for info in t[CcRuleInfoSet].cc_infos
    ]

    # Run on all cc_infos, skipping duplicates
    outfiles = []
    cc_dict = {}
    for cc_info, compilation_context in cc_infos:
        l = cc_info["label"]
        name = "@{}//{}:{}".format(l.workspace_name, l.package, l.name)
        if not name in cc_dict:
            cc_dict[name] = cc_info

            # Run clang tidy on this cc_rule
            outfiles += gen_tidy_logic(
                ctx,
                compilation_context,
                cc_info["label"],
                cc_info["kind"],
                cc_info["attr"],
                cc_info["srcs"],
                llvm_filter_args(cc_info["cflags"]),
                llvm_filter_args(cc_info["cxxflags"]),
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
    },
)