"""
Common functions for installable toolchain helpers
"""

load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")

def is_workspace_target(target):
    return target.label.workspace_name == ""

def is_c_file(file):
    return file.path.endswith(".c")

def is_cc_rule(rule):
    return rule.kind in ["cc_binary", "cc_library", "cc_shared_library", "cc_test"]

HDR_FTYPES = [".h", ".hh", ".hpp", ".hxx", ".H"]

SRC_FTYPES = [".c", ".cc", ".cpp", ".cxx", ".c++", ".C"]

ALL_FTYPES = HDR_FTYPES + SRC_FTYPES

def is_valid_hdr_file(file):
    """Tests if the passed file (object) is a header

    Args:
      file: The file to test

    Returns:
      True or False =)
    """
    for type in HDR_FTYPES:
        if file.basename.endswith(type):
            return True
    return False

def is_valid_src_hdr_file(file):
    """Tests if the passed file (object) is a C++ source/header

    Args:
      file: The file to test

    Returns:
      True or False =)
    """
    for type in ALL_FTYPES:
        if file.basename.endswith(type):
            return True
    return False

def is_valid_src_file(file):
    return file.is_source and is_valid_src_hdr_file(file)

# -- Aspect to collect C++ source and header files

def rule_cc_sources(rule):
    """The source/header files of a CC rule, or empty

    Args:
      rule: The rule being queried

    Returns:
      A list of bazel file objects
    """
    files = []
    if is_cc_rule(rule):
        if hasattr(rule.attr, "srcs"):
            for src in rule.attr.srcs:
                files += [file for file in src.files.to_list() if is_valid_src_hdr_file(file)]
        if hasattr(rule.attr, "hdrs"):
            for hdr in rule.attr.hdrs:
                files += [file for file in hdr.files.to_list() if is_valid_src_hdr_file(file)]
    return files

def _collect_cc_dependencies_impl(target, ctx):
    files = rule_cc_sources(ctx.rule) if is_workspace_target(target) else []
    collected = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            collected.append(dep[OutputGroupInfo]._collected_cc_deps)

    return [OutputGroupInfo(_collected_cc_deps = depset(files, transitive = collected))]

collect_cc_dependencies = aspect(
    implementation = _collect_cc_dependencies_impl,
    attr_aspects = ["deps"],
)

# -- For joining compiler commands with compiler_context flags

def get_compiler_context_flags(compilation_context):
    args = []
    args += ["-D" + d for d in compilation_context.defines.to_list()] 
    args += ["-D" + d for d in compilation_context.local_defines.to_list()]
    args += ["-F" + f for f in compilation_context.framework_includes.to_list()]
    args += ["-I" + i for i in compilation_context.includes.to_list()]
    args += ["-iquote" + q for q in compilation_context.quote_includes.to_list()]
    args += ["-isystem" + q for q in compilation_context.external_includes.to_list()]
    args += ["-isystem" + s for s in compilation_context.system_includes.to_list()]
    return args

def append_compiler_context_flags(flags, compilation_context):
    """Adds the 'compilation context' flags to a list of compile flags.

    Args:
      flags: A list of compile flags, like ["-Wall", ...]
      compilation_context: Comes from a CcInfo providers

    Returns:
      A full list of flags, including [-D..., -isystem..., ...] from the toolchain context
    """
    return [x for x in flags] + get_compiler_context_flags(compilation_context)

# -- Aspect to get everything about CC deps

CcRuleSetInfo = provider(
    "Rule info for cc build rules, necessary for regenerating compiler flags",
    fields = {
        "cc_infos": "a list of structs [{'kind', 'attr'}, ...]",
        "lookup": "maps names => cc_infos",
    },
)

def _calculate_toolchain_flags(ctx, action_name):
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
    )
    compile_variables = cc_common.create_compile_variables(
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        user_compile_flags = ctx.fragments.cpp.cxxopts + ctx.fragments.cpp.copts,
    )
    flags = cc_common.get_memory_inefficient_command_line(
        feature_configuration = feature_configuration,
        action_name = action_name,
        variables = compile_variables,
    )
    return flags

def _collect_cc_actions_impl(target, ctx):
    collected = []
    lookup = {}
    
    name = "@{}//{}:{}".format(ctx.label.workspace_name, ctx.label.package, ctx.label.name)

    if is_cc_rule(ctx.rule) and name not in lookup: # and is_workspace_target(target):
        srcs = []
        
        if hasattr(ctx.rule.attr, "srcs"):
            for src in ctx.rule.attr.srcs:
                srcs += [s for s in src.files.to_list() if is_valid_src_file(s)]

        # Lazily generate the C/C++ flags for this rule, based on activated features
        cflags = None
        cxxflags = None
        linkflags = None
        for src in srcs:
            if not cflags and is_c_file(src):
                cflags = _calculate_toolchain_flags(ctx, ACTION_NAMES.c_compile)
            elif not cxxflags:
                cxxflags = _calculate_toolchain_flags(ctx, ACTION_NAMES.cpp_compile)
        if not cflags:
            cflags = []
        if not cxxflags:
            cxxflags = []

        # Add per-rule copts
        if hasattr(ctx.rule.attr, "copts"):
            cflags = cflags + ctx.rule.attr.copts
            cxxflags = cxxflags + ctx.rule.attr.copts

        info = {
            "name": name,
            "label": ctx.label,
            "kind": ctx.rule.kind,
            "attr": ctx.rule.attr,
            "srcs": srcs,
            "cflags": cflags,
            "cxxflags": cxxflags,
            "in_workspace": is_workspace_target(target),
        }

        lookup[name] = info
        collected += [info]
        
        if hasattr(ctx.rule.attr, "deps"):
            for dep in ctx.rule.attr.deps:
                if CcRuleSetInfo in dep:
                    for key, value in dep[CcRuleSetInfo].lookup.items():
                        if key in lookup:
                            continue
                        lookup[key] = value
                        collected += [value]
    return [CcRuleSetInfo(cc_infos = collected, lookup = lookup)]

collect_cc_actions = aspect(
    implementation = _collect_cc_actions_impl,
    fragments = ["cpp"],
    attr_aspects = ["deps"],
    attrs = {
        "_cc_toolchains": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    provides = [CcRuleSetInfo],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
