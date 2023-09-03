load("@hedron_compile_commands//:refresh_compile_commands.bzl", "refresh_compile_commands")
load("@com_github_bazelbuild_buildtools//buildifier:def.bzl", "buildifier")
load("//internal:defs.bzl", "clang_format")

exports_files([
    ".clang-format",
])

filegroup(
    name = "clang_tidy_config",
    srcs = [".clang-tidy"],
    visibility = ["//visibility:public"],
)

alias(
    name = "clang_tidy_bin",  # Pass through to whatever clang-tidy is installed
    actual = "@initialize_toolchain//:clang_tidy_bin",
)

refresh_compile_commands(
    name = "refresh_compile_commands",
    targets = {
        "//example/...": "--config=compdb",
    },
)

buildifier(
    name = "buildifier_check",
    # exclude_patterns = ["glob-pattern", ...]
    lint_mode = "warn",
    verbose = False,
)

buildifier(
    name = "buildifier_fix",
    # exclude_patterns = ["glob-pattern", ...]
    lint_mode = "fix",
    verbose = True,
)

clang_format(
    name = "format_check",
    clang_format = "@initialize_toolchain//:clang_format_bin",
    targets = ["//example/src:main"],
    mode = "check",
)

clang_format(
    name = "format_fix",
    clang_format = "@initialize_toolchain//:clang_format_bin",
    targets = ["//example/src:main"],
    mode = "fix",
)

