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
    host_cxx_builtin_dirs = HOST_CXX_BUILTIN_DIRS,
    is_default = USE_HOST_COMPILER,
)

# -- Clang Tidy

binary_alias(
    name = "clangtidy_bin",
    src = TOOLCHAIN_DIRECTORY + "/bin/clang-tidy",
)

# -- Files the compiler has access to

filegroup(
    name = "compiler_deps",
    srcs = []
)
