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
    for type in SRC_FTYPES:
        if file.basename.endswith(type):
            return True
    return False

def is_valid_shared_library(file):
    return file.basename.endswith(".so")

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
                files += [file for file in src.files.to_list()]
        if hasattr(rule.attr, "hdrs"):
            for hdr in rule.attr.hdrs:
                files += [file for file in hdr.files.to_list()]
        if hasattr(rule.attr, "textual_hdrs"):
            for hdr in rule.attr.textual_hdrs:
                files += [file for file in hdr.files.to_list()]
    return files

def rule_cc_headers(rule):
    """The source/header files of a CC rule, or empty

    Args:
      rule: The rule being queried

    Returns:
      A list of bazel file objects
    """
    files = []
    if is_cc_rule(rule):
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
    if hasattr(compilation_context, "external_includes"):
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

def _uniquify_list(items, thunk = None):
    set = {}
    out = []
    for item in items:
        key = thunk(item) if thunk else item
        if key in set:
            continue
        set[key] = True
        out += [item]
    return out

def _file_to_label(filename):
    idx = filename.rfind("/")
    if idx >= 0 and filename.find(".pb.") < 0:
        return "//{}:{}".format(filename[0:idx], filename[idx+1:])
    return "//{}".format(filename)

def _file_to_rel_label(label, so_name):
    if not label.startswith("@//"):
        return _file_to_label(so_name)
    label = label[3:]
    index = label.find(":")
    if index < 0:
        return _file_to_label(so_name)
    root = label[0:index]
    if so_name.startswith(root):
        return "//{}:{}".format(root, so_name[index+1:])
    return _file_to_label(so_name)

def _is_pb_srcs(info):
    for src in info["srcs"] + info["hdrs"]:
        if src.path.endswith(".pb.h") or src.path.endswith(".pb.cc") or src.path.endswith(".pb.validate.cc") or src.path.endswith(".pb.validate.h"):
            return True
    return False

def _workspace_dep(info, rule):
    return info["in_workspace"] and rule.kind.find("proto") < 0 and not _is_pb_srcs(info)

def _rule_directory(name):
    if not name.startswith("@"):
        return
    name = name[1:]
    index = name.find("//")
    if index < 0:
        return ""
    start = name[0:index]
    name = name[index+2:]
    index = name.rfind(":")
    if index < 0:
        return ""
    name = name[0:index]
    if start == "":
        return name
    return "bazel-bin/external/{}/{}".format(start, name)

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

def collect_cc_actions_impl(target, ctx):
    collected = []
    lookup = {}
    
    name = "@{}//{}:{}".format(ctx.label.workspace_name, ctx.label.package, ctx.label.name)
    is_proto_rule = ctx.rule.kind.find("proto") >= 0
    is_cc_rule = CcInfo in target
    
    unity_src_file = ctx.actions.declare_file(ctx.label.name + ".unity.cpp")
    unity_build_file = ctx.actions.declare_file(ctx.label.name + ".unity.BUILD.bazel")
    include_stmts = ""
    build_file_contents = ""
    
    if is_cc_rule and name not in lookup: # and is_workspace_target(target):
        src_hdrs = rule_cc_sources(ctx.rule)
        srcs = [f for f in src_hdrs if is_valid_src_file(f)]
        hdrs = [f for f in src_hdrs if is_valid_hdr_file(f)]
        so_srcs = [f for f in src_hdrs if is_valid_shared_library(f)]
        
        # Lazily generate the C/C++ flags for this rule, based on activated features
        cflags = None
        cxxflags = None
        for src in srcs:
            if not cflags and is_c_file(src):
                cflags = _calculate_toolchain_flags(ctx, ACTION_NAMES.c_compile)
            elif not cxxflags:
                cxxflags = _calculate_toolchain_flags(ctx, ACTION_NAMES.cpp_compile)
        if not cflags:
            cflags = []
        if not cxxflags:
            cxxflags = []

        linkflags = []
        if ctx.rule.kind == "cc_binary":
            linkflags = _calculate_toolchain_flags(ctx, ACTION_NAMES.cpp_link_executable)
            
        # Add per-rule copts
        copts = ctx.rule.attr.copts if hasattr(ctx.rule.attr, "copts") else []
        conlyopts = ctx.rule.attr.conlyopts if hasattr(ctx.rule.attr, "conlyopts") else []
        cxxopts = ctx.rule.attr.cxxopts if hasattr(ctx.rule.attr, "cxxopts") else []
        linkopts = ctx.rule.attr.linkopts if hasattr(ctx.rule.attr, "linkopts") else []
        
        cflags = cflags + copts + conlyopts
        cxxflags = cxxflags + copts + cxxopts

        data = ctx.rule.attr.data if hasattr(ctx.rule.attr, "data") else []
        include_prefixes = [ctx.rule.attr.include_prefix] if hasattr(ctx.rule.attr, "include_prefix") else []
        includes = ctx.rule.attr.includes if hasattr(ctx.rule.attr, "includes") else []

        rule_dir = _rule_directory(name)
        includes = [rule_dir if i == "." else i for i in includes]

        info = {
            "name": name,
            "label": ctx.label,
            "kind": ctx.rule.kind,
            "attr": ctx.rule.attr,
            "srcs": srcs,
            "hdrs": hdrs,
            "so_srcs": [_file_to_rel_label(name, so.path) for so in so_srcs],
            "data": data,
            "include_prefix": include_prefixes,
            "includes": includes,
            "cflags": cflags,
            "cxxflags": cxxflags,
            "linkflags": linkflags,
            "copts": copts,
            "conlyopts": conlyopts,
            "cxxopts": cxxopts,
            "linkopts": linkopts,
            "is_proto_rule": is_proto_rule,
            "in_workspace": is_workspace_target(target),
        }
        
        lookup[name] = info
        collected += [info]
        
        if hasattr(ctx.rule.attr, "deps") and info["in_workspace"]:
            for dep in ctx.rule.attr.deps:
                if "{}".format(dep.label).endswith("protobuf_layering_check_legacy"):
                    continue # This dependency is blacklisted
                if CcRuleSetInfo in dep:
                    for key, value in dep[CcRuleSetInfo].lookup.items():                        
                        # print("KEY: ", key)
                        lookup[key] = value
                        collected += [value]

        # Uniquify "collected"
        collected = _uniquify_list(collected, lambda x: x["name"])

        workspace_proto_deps = [i["name"] for i in collected if i["is_proto_rule"] and i["in_workspace"]]                
        all_deps = _uniquify_list([i["name"] for i in collected if not _workspace_dep(i, ctx.rule)] + workspace_proto_deps)
        out_infos = [i for i in collected if _workspace_dep(i, ctx.rule)]
        
        out_srcs = _uniquify_list([x for infos in out_infos for x in infos["srcs"]])
        out_hdrs = _uniquify_list([x for infos in out_infos for x in infos["hdrs"]])
        out_all = out_srcs + out_hdrs

        textual_hdrs = _uniquify_list([_file_to_label(f.short_path) for f in out_all])

        extra_includes_dirs = _uniquify_list([x for i in out_infos for x in i["includes"]] + ["source", "include"])
        extra_includes = ["-I{}".format(x) for x in extra_includes_dirs]
        
        all_copts = _uniquify_list([x for i in out_infos for x in i["copts"]] + extra_includes)
        all_conlyopts = _uniquify_list([x for i in out_infos for x in i["conlyopts"]])
        all_cxxopts = _uniquify_list([x for i in out_infos for x in i["cxxopts"]])
        all_linkopts = _uniquify_list([x for i in out_infos for x in i["linkopts"]])

        all_data = [x for i in out_infos for x in i["data"]]
        
        # Make the Unity cpp file
        include_stmts = "\n".join(["#include \"" + file.path + "\"" for file in out_srcs])
        
        # Make the Unity BUILD file
        conlyopts_str = "\n    conlyopts = {},".format(all_conlyopts) if len(all_conlyopts) > 0 else ""
        cxxopts_str = "\n    cxxopts = {},".format(all_cxxopts) if len(all_cxxopts) > 0 else ""

        all_so_libs = _uniquify_list([x for i in out_infos for x in i["so_srcs"]])

        # it_is = name.endswith(":cple_sg_so_lib")
        # if it_is:
        #     print("NAME: ", name)
        #     for k, v in info.items():
        #         print("K", k, v)
        #     print("SO_DEPS", so_srcs)
        #     print("ALL_SO_DEPS", all_so_libs)
        #     fail("foo")
            
        build_file_contents = """
cc_library(
    name = "{0}_lib",
    srcs = ["{0}.unity.cpp"],
    copts = {1},{2}{3}
    linkopts = {4},
    textual_hdrs = {5},
    deps = {6},
    visibility = ["//visibility:public"],
)

cc_binary(
    name = "{0}",
    srcs = {8},
    data = {7},
    deps = [":{0}_lib"],
    visibility = ["//visibility:public"],
)

        """.format(ctx.label.name,
                   all_copts, conlyopts_str, cxxopts_str, all_linkopts, textual_hdrs, all_deps, all_data, all_so_libs)

    ctx.actions.write(unity_src_file, include_stmts)
    ctx.actions.write(unity_build_file, build_file_contents)
        
    return [
        CcRuleSetInfo(cc_infos = collected, lookup = lookup),
        OutputGroupInfo(unity_files = depset([unity_src_file, unity_build_file])),
    ]

collect_cc_actions = aspect(
    implementation = collect_cc_actions_impl,
    fragments = ["cpp"],
    attr_aspects = ["deps"],
    attrs = {
        "_cc_toolchains": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    provides = [CcRuleSetInfo, OutputGroupInfo],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
