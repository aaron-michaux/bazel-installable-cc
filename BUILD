load("@hedron_compile_commands//:refresh_compile_commands.bzl", "refresh_compile_commands")

exports_files([
    ".clang-format",
])

filegroup(
    name = "clang_tidy_config",
    srcs = [".clang-tidy"],
    visibility = ["//visibility:public"],
)

alias(
    name = "clang_tidy_bin", # Pass through to whatever clang-tidy is installed
    actual = "@initialize_toolchain//:clang_tidy_bin",
)

refresh_compile_commands(
    name = "refresh_compile_commands",
    targets = {
        "//example/...": "--config=compdb",
    },
)

