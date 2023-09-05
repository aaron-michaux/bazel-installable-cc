load("@com_github_bazelbuild_buildtools//buildifier:def.bzl", "buildifier")
load("@initialize_toolchain//:defs.bzl", "clang_format", "clang_tidy")

exports_files([
    ".clang-format",
    ".clang-tidy",
])

# -- Targets
# There's two clang format rules (check and fix), 1 tidy rule, and 1 refresh comp command rule
# We'd like them to all work across the same set of targets. So the targets are specified here.

FORMAT_TIDY_TARGETS = ["//example/src:main"]

# -- Buildifier

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

# -- Clang Format

filegroup(
    name = "clang_format_config",
    srcs = [".clang-format"],
)

alias(
    name = "clang_format_bin",
    actual = "@initialize_toolchain//:clang_format_bin",
)

clang_format(
    name = "format_check",
    clang_format = ":clang_format_bin",
    config_file = ":clang_format_config",
    mode = "check",
    targets = FORMAT_TIDY_TARGETS,
)

clang_format(
    name = "format_fix",
    clang_format = ":clang_format_bin",
    config_file = ":clang_format_config",
    mode = "fix",
    targets = FORMAT_TIDY_TARGETS,
)

# -- Clang Tidy

filegroup(
    name = "clang_tidy_config",
    srcs = [".clang-tidy"],
)

alias(
    name = "clang_tidy_bin",  # Pass through to whatever clang-tidy is installed
    actual = "@initialize_toolchain//:clang_tidy_bin",
)

clang_tidy(
    name = "static_analysis",
    clang_tidy = ":clang_tidy_bin",
    config_file = ":clang_tidy_config",
    targets = FORMAT_TIDY_TARGETS,
)
