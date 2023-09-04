load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

load(":common.bzl", "collect_cc_dependencies", "is_workspace_target",
     "is_c_file", "rule_cc_sources", "CcRuleInfoSet", "collect_cc_actions", "is_valid_src_file",
     "append_compiler_context_flags")

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
        tools += [ctx.executable.clang_tidy]        
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

    rule_flags = attr.copts if hasattr(attr, "copts") else []
    
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
            inputs = calc_inputs(src, config_file, compilation_context),
            outputs = [outfile],
            arguments = [args],
            mnemonic = "ClangTidy",
            tools = tools,
            command = command
        )
        
    return outputs

def _clang_tidy_check_impl(ctx):

    # A list of cc_rules
    cc_infos = [(info, t[CcInfo].compilation_context)
                 for t in ctx.attr.targets for info in t[CcRuleInfoSet].cc_infos]

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
                llvm_filter_args(cc_info["cxxflags"])
            )
            
    return [DefaultInfo(files = depset(outfiles))]
    
#     inputs = [file for target in ctx.attr.targets
#               for file in target[OutputGroupInfo]._collected_cc_deps.to_list()] 
#     outfiles = []
#     for file in inputs:
#         outfile = ctx.actions.declare_file(file.path + ".clang-tidy")
#         outfiles.append(outfile)

#         command = """
# rm -f {3} && touch {3}
# [ -e .clang-tidy ] || ln -s -f "{}" .clang-tidy

# {0} {1} {2} && touch {3}
# """.format(exe, config_arg, file.path, outfile.path)

#         inputs = [file]
#         if ctx.attr.config_file:
#             inputs.append(config_file)
        
#         ctx.actions.run_shell(
#             inputs = inputs,
#             outputs = [outfile],
#             tools = tools,
#             command = command,
#         )
    
#     return [DefaultInfo(files = depset(outfiles))]
    
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
    }
)






