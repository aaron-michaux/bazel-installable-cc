"""
This file ties together available toolchains, and default flags.
In theory this file could be machine-generated from the manifest, in the repo_ctx rule.
"""

load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load(
    ":toolchain_common.bzl",
    "make_toolchain_from_install_root",
    "binary_alias",
)
load(":toolchain_flags.bzl", "TOOLCHAIN_FLAGS")
load("@toolchain_initialization//:config.bzl", "TOOLCHAIN_PREFIX")     

package(default_visibility = ["//visibility:public"])

# -- The configured toolchains

# "/opt/toolchains"
_TOOLCHAIN_PREFIX = TOOLCHAIN_PREFIX

filegroup(
    name = "manifest",
    srcs = "manifest.text",
)

_GCC9 = "gcc-9.5.0"
_GCC10 = "gcc-10.5.0"
_GCC11 = "gcc-11.4.0"
_GCC12 = "gcc-12.3.0"
_GCC13 = "gcc-13.2.0"
_LLVM13 = "clang-13.0.1"
_LLVM14 = "clang-14.0.6"
_LLVM15 = "clang-15.0.7"
_LLVM16 = "clang-16.0.6"
_LLVM = _LLVM16

AVAILABLE_COMPILERS = {
    "gcc": "/usr",
    "gcc9": _GCC9,
    "gcc10": _GCC10,
    "gcc11": _GCC11,
    "gcc12": _GCC12,
    "gcc13": _GCC13,
    "llvm": _LLVM16,
    "llvm13": _LLVM13,
    "llvm14": _LLVM14,
    "llvm15": _LLVM15,
    "llvm16": _LLVM16,
}

# -- To switch between gcc/clang

string_flag(
    name = "compiler",
    build_setting_default = "gcc",
    values = [key for key, value in AVAILABLE_COMPILERS.items()]
)
config_setting(name = "compiler_gcc", flag_values = {":compiler": "gcc"})
config_setting(name = "compiler_gcc9", flag_values = {":compiler": "gcc9"})
config_setting(name = "compiler_gcc10", flag_values = {":compiler": "gcc10"})
config_setting(name = "compiler_gcc11", flag_values = {":compiler": "gcc11"})
config_setting(name = "compiler_gcc12", flag_values = {":compiler": "gcc12"})
config_setting(name = "compiler_gcc13", flag_values = {":compiler": "gcc13"})
config_setting(name = "compiler_llvm13", flag_values = {":compiler": "llvm13"})
config_setting(name = "compiler_llvm14", flag_values = {":compiler": "llvm14"})
config_setting(name = "compiler_llvm15", flag_values = {":compiler": "llvm15"})
config_setting(name = "compiler_llvm16", flag_values = {":compiler": "llvm16"})

# -- System toolchain

make_toolchain_from_install_root(
    install_root = "/usr",
    additional_args = TOOLCHAIN_FLAGS,
)

# -- Gcc

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _GCC9,
    additional_args = TOOLCHAIN_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _GCC10,
    additional_args = TOOLCHAIN_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _GCC11,
    additional_args = TOOLCHAIN_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _GCC12,
    additional_args = TOOLCHAIN_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _GCC13,
    additional_args = TOOLCHAIN_FLAGS,
)

# -- Llvm

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _LLVM13,
    additional_args = TOOLCHAIN_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _LLVM14,
    additional_args = TOOLCHAIN_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _LLVM15,
    additional_args = TOOLCHAIN_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_PREFIX + "/" + _LLVM16,
    additional_args = TOOLCHAIN_FLAGS,
)

# -- Clang Tidy

binary_alias(
    name = "clangtidy_bin",
    src = select({        
        ":compiler_llvm13": _TOOLCHAIN_PREFIX + "/" + _LLVM13 + "/bin/clang-tidy",
        ":compiler_llvm14": _TOOLCHAIN_PREFIX + "/" + _LLVM14 + "/bin/clang-tidy",
        ":compiler_llvm15": _TOOLCHAIN_PREFIX + "/" + _LLVM15 + "/bin/clang-tidy",
        ":compiler_llvm16": _TOOLCHAIN_PREFIX + "/" + _LLVM16 + "/bin/clang-tidy",
        "//conditions:default": _TOOLCHAIN_PREFIX + "/" + _LLVM + "/bin/clang-tidy",
    })
)

# -- Files the compiler has access to

filegroup(
    name = "compiler_deps",
    srcs = []
)

# -- Selected

alias(
    name = "cpp",
    actual = select({
        ":compiler_gcc": ":gcc",
        ":compiler_gcc9": ":" + _GCC9,
        ":compiler_gcc10": ":" + _GCC10,
        ":compiler_gcc11": ":" + _GCC11,
        ":compiler_gcc12": ":" + _GCC12,
        ":compiler_gcc13": ":" + _GCC13,
        ":compiler_llvm13": ":" + _LLVM13,
        ":compiler_llvm14": ":" + _LLVM14,
        ":compiler_llvm15": ":" + _LLVM15,
        ":compiler_llvm16": ":" + _LLVM16,
        "//conditions:default": ":gcc",
    }),
)


