"""
Module for generate `makefile`
"""

load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load(
    ":common.bzl",
    "CcRuleSetInfo",
    "append_compiler_context_flags",
    "collect_cc_actions",
    "is_c_file",
    "is_valid_hdr_file",
)

# -- Make makefile

def _gen_compile_commands_logic(ctx, compilation_context, compiler_exe, label, kind, attr, srcs, cflags, cxxflags):
    is_cc_rule = kind.startswith("cc_")

    def make_comp_commands(src):
        is_c = is_c_file(src)
        is_header = is_valid_hdr_file(src)

        lang = "c" if is_c else "c++"
        if is_header:
            lang += "-header"

        flags = append_compiler_context_flags(cflags if is_c else cxxflags, compilation_context)

        parts = src.path.split(".")
        if len(parts) > 1:
            parts.pop()
        objfile_path = ".".join(parts) + ".o"
        return {
            "directory": ".",
            "file": src.path,
            "output": objfile_path,
            "arguments": [compiler_exe] + ["-x", lang] + flags + ["-o", objfile_path] + [src.path],
        }

    return [make_comp_commands(src) for src in srcs]

def _make_makefile_impl(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    compiler_exe = cc_toolchain.compiler_executable

    # A list of cc_rules
    cc_infos = [
        (info, t[CcInfo].compilation_context)
        for t in ctx.attr.targets
        for info in t[CcRuleSetInfo].cc_infos
    ]

    # Run on all cc_infos, skipping duplicates
    outputs = []
    cc_dict = {}
    for cc_info, compilation_context in cc_infos:
        label = cc_info["label"]
        name = "@{}//{}:{}".format(label.workspace_name, label.package, label.name)
        if not name in cc_dict:
            cc_dict[name] = cc_info
            outputs += _gen_compile_commands_logic(
                ctx,
                compilation_context,
                compiler_exe,
                cc_info["label"],
                cc_info["kind"],
                cc_info["attr"],
                cc_info["srcs"],
                cc_info["cflags"],
                cc_info["cxxflags"],
            )

    # Bring it all together for a single compdb file
    outfile = ctx.actions.declare_file("makefile")
    ctx.actions.write(
        output = outfile,
        is_executable = False,
        content = json.encode_indent(outputs) if ctx.attr.indent else json.encode(outputs),
    )

    return [DefaultInfo(files = depset([outfile]))]

make_makefile_internal = rule(
    implementation = _make_makefile_impl,
    attrs = {
        "targets": attr.label_list(aspects = [collect_cc_actions]),
        "indent": attr.bool(default = False),  # Makes database larger bigger
    },
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
