load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load(":common.bzl",
     "is_c_file", "CcRuleInfoSet", "collect_cc_actions", "is_valid_src_file",
     "append_compiler_context_flags")

# -- Compile commands

    

def gen_compile_commands_logic(ctx, compilation_context, compiler_exe, label, kind, attr, srcs, cflags, cxxflags):

    def make_comp_commands(src):
        is_c = is_c_file(src)
        flags = append_compiler_context_flags(cflags if is_c else cxxflags, compilation_context)

        parts = src.path.split(".")
        if len(parts) > 1:
            parts.pop()
        objfile_path = ".".join(parts) + ".o"
        
        return {
            "directory": ".",
            "file": src.path,
            "output": objfile_path,
            "arguments": [compiler_exe] + ["-x", "c" if is_c else "c++"] + flags + ["-o", objfile_path],
        }

    return [make_comp_commands(src) for src in srcs]

def _compile_commands_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    compiler_exe = cc_toolchain.compiler_executable
    
    # A list of cc_rules
    cc_infos = [(info, t[CcInfo].compilation_context)
                 for t in ctx.attr.targets for info in t[CcRuleInfoSet].cc_infos]

    # Run on all cc_infos, skipping duplicates
    outputs = []
    cc_dict = {}
    for cc_info, compilation_context in cc_infos:        
        l = cc_info["label"]
        name = "@{}//{}:{}".format(l.workspace_name, l.package, l.name)
        if not name in cc_dict:            
            cc_dict[name] = cc_info
            outputs += gen_compile_commands_logic(
                ctx,
                compilation_context,
                compiler_exe,
                cc_info["label"],
                cc_info["kind"],
                cc_info["attr"],
                cc_info["srcs"],
                cc_info["cflags"],
                cc_info["cxxflags"]
            )

    # Bring it all together for a single compdb file
    outfile = ctx.actions.declare_file("compilation_database.json")
    ctx.actions.write(
        output = outfile,
        is_executable = False,
        content = json.encode_indent(outputs) if ctx.attr.indent else json.encode(outputs)
    )
    
    return [DefaultInfo(files = depset([outfile]))]
    
compile_commands_internal = rule(
    implementation = _compile_commands_impl,
    attrs = {
        "targets": attr.label_list(aspects = [collect_cc_actions]),
        "indent": attr.bool(default = False), # Makes database larger bigger
    },    
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)

