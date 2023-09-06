"""
Specifies the compiler configured through @initialize_toolchain://cc
"""

# load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load(":toolchain_common.bzl", "make_toolchain_from_install_root", "binary_alias")

package(default_visibility = ["//visibility:public"])

TOOLCHAIN_DIRECTORY = %{toolchain_directory}

SYS_MACHINE = %{sysmachine}

HOST_CXX_BUILTIN_DIRS = %{host_cxx_builtin_dirs}

USE_HOST_COMPILER = %{use_host_compiler}

TOOLCHAIN_FLAGS = %{toolchain_flags}

make_toolchain_from_install_root(
    name = "cc",
    install_root = TOOLCHAIN_DIRECTORY,
    additional_args = TOOLCHAIN_FLAGS,
    sys_machine = SYS_MACHINE,
    host_cxx_builtin_dirs = HOST_CXX_BUILTIN_DIRS, # Use for MacOS (brew), or host compilers
    is_host_compiler = USE_HOST_COMPILER,
    operating_system = %{os},
)

alias(
    name = "cc_configuration",
    actual = ":cc_config",
)

# -- Clang Tidy
# Override this values on the commandline:
# build:static_analysis --@<this_repo_name>//:clang_tidy_bin=//path/to/your/clang/tidy
#      For example: --@initialize_toolchain//:clang_tidy_bin=//:clang_tidy_bin
binary_alias(
    name = "clang_tidy_executable",
    src = TOOLCHAIN_DIRECTORY + "/bin/clang-tidy",
)

filegroup(
    name = "compile_commands_default",
    srcs = ["compile_commands.json"]
)

filegroup(
    name = "clang_tidy_config_default",
    srcs = [".clang-tidy"]
)

label_flag(
    name = "clang_tidy_bin",
    build_setting_default = ":clang_tidy_executable",
)

label_flag(
    name = "clang_tidy_config",
    build_setting_default = ":clang_tidy_config_default",
)

label_flag(
    name = "compile_commands",
    build_setting_default = ":compile_commands_default",
)

# -- Clang Format

binary_alias(
    name = "clang_format_bin",
    src = TOOLCHAIN_DIRECTORY + "/bin/clang-format",
)

# -- Files the compiler has access to

filegroup(
    name = "compiler_deps",
    srcs = []
)
