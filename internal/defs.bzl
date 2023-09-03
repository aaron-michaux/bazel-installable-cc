def is_cc_rule_of_interest(rule):
    return rule.kind in ["cc_binary", "cc_library"] and hasattr(rule.attr, "srcs") and len(rule.attr.srcs) > 0

# -- Aspect to collect C++ dependencies

def _collect_cc_dependencies_impl(target, ctx):
    files = []
    if is_cc_rule_of_interest(ctx.rule):
        for srcs in ctx.rule.attr.srcs:
            for file in srcs.files.to_list():
                files.append(file)
    
    collected = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            collected.append(dep[OutputGroupInfo]._collected_cc_deps)

    return [OutputGroupInfo(_collected_cc_deps = depset(files, transitive = collected))]
    
collect_cc_dependencies = aspect(
    implementation = _collect_cc_dependencies_impl,
    attr_aspects = ["deps"],
)

# -- Runs clang-format
    
def _clang_format_check_impl(ctx):
    is_check_only = (ctx.attr.mode == "check")
    flags = "-n -Werror" if is_check_only else "-i"
    clang_format_path = ctx.executable.clang_format.path
    extension = ".format-check" if is_check_only else ".format-fix"
    
    inputs = [file for target in ctx.attr.targets
              for file in target[OutputGroupInfo]._collected_cc_deps.to_list()] 
    outfiles = []
    for file in inputs:
        outfile = ctx.actions.declare_file(file.path + extension)
        outfiles.append(outfile)

        command = "{} -n -Werror {} && touch {}".format(clang_format_path, file.path, outfile.path)
        if not is_check_only:
            command = "{} -i {} && {}".format(clang_format_path, file.path, command)
        
        ctx.actions.run_shell(
            inputs = [file],
            outputs = [outfile],
            tools = [ctx.executable.clang_format],
            command = command,
        )
    
    return [DefaultInfo(files = depset(outfiles))]

clang_format = rule(
    implementation = _clang_format_check_impl,
    attrs = {
        "targets": attr.label_list(aspects = [collect_cc_dependencies]),
        "clang_format": attr.label(
            default = Label("@initialize_toolchain//:clang_format_bin"),
            executable = True,
            cfg = "exec"
        ),
        "mode": attr.string(values = ["check", "fix"], mandatory = True)
    }
)

