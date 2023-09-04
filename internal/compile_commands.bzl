# NOTE: to use `compile_comands.bzl`, initialize must be called with name="initialize_toolchain"(
load("@initialize_toolchain//:toolchain_common.bzl", "ToolPathsAndFeaturesInfo")
load(":defs.bzl", "is_workspace_target", "is_cc_rule")

CcRuleInfoSet = provider(
    "A cc build rule of some kind",
    fields = {
        "cc_infos": "a list of structs [{'kind', 'attr'}, ...]",
    }
)

def _cc_actions_aspect_impl(target, ctx):
    collected = []
    if is_cc_rule(ctx.rule) and is_workspace_target(target):
        collected = [{"kind": ctx.rule.kind, "attr": ctx.rule.attr}]
        if hasattr(ctx.rule.attr, "deps"):
            for dep in ctx.rule.attr.deps:
                if CcRuleInfoSet in dep:
                    collected += dep[CcRuleInfoSet].cc_infos
    return [CcRuleInfoSet(cc_infos = collected)]
    
cc_actions_aspect = aspect(
    implementation = _cc_actions_aspect_impl,
    attr_aspects = ["deps"],
    provides = [CcRuleInfoSet]
)

# --

def parse_toolchain_config_info(s):
    # key: value (string, bool...)
    # typename { ... }

    
    pass

# -- Compile commands

def _compile_commands_impl(ctx):
    """Get the compile commands for a list of targets

    Limitations: 
     * This is no access to command line options like --copts, thus
       all compile options should be switched on/off through features.
     * An individual package can toggle features; however, there's no
       way for an action to query which features are on/off. 
    """
    info = ctx.attr.cc_configuration[ToolPathsAndFeaturesInfo]
    tool_paths = info.tool_paths
    features = info.features

    # Input files... only interested in '.cc' files
    # all_inputs = [file for target in ctx.attr.targets
    #               for file in target[OutputGroupInfo]._collected_cc_deps.to_list()]
    # inputs = [f for f in all_inputs if is_cc_file(f.path)]

    #CC_TOOLCHAIN_TYPE = "@bazel_tools//tools/cpp:toolchain_type"

    # Type is `CcToolchainInfo`
 
    # We could parse this list of "json-like" structure to get the toolchain info

    inputs = [cc_info for target in ctx.attr.targets
              for cc_info in target[CcRuleInfoSet].cc_infos] 
    print("INPUTS: ", inputs)
    
    cc_config = ctx.attr.cc_configuration[CcToolchainConfigInfo]
    print(parse_toolchain_config_info(cc_config.proto))

    print(ctx.features)
    print(ctx.var)
    print(ctx.configuration)
    
    return []

compile_commands_internal = rule(
    implementation = _compile_commands_impl,
    attrs = {
        "targets": attr.label_list(aspects = [cc_actions_aspect]),
        "cc_configuration": attr.label(mandatory = True),
    },    
)



