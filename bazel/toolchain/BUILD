load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("@bazel_skylib//rules:native_binary.bzl", "native_binary")
load(
    ":toolchain_common.bzl",
    "make_toolchain_from_install_root",
    "binary_alias",
)
load(":toolchain_flags.bzl", "COMPILE_LINK_FLAGS")
load("@toolchain_initialization//:config.bzl", "TOOLCHAIN_ROOT")     

package(default_visibility = ["//visibility:public"])

# -- The configured toolchains

# "/opt/toolchains"
_TOOLCHAIN_ROOT = TOOLCHAIN_ROOT 

_GCC12 = "gcc-12.2.0"
_GCC13 = "gcc-13.1.0"
_CLANG15 = "clang-15.0.6"
_CLANG16 = "clang-16.0.2"
_CLANG = _CLANG16

AVAILABLE_COMPILERS = {
    "gcc": "/usr",
    "gcc12": _GCC12,
    "gcc13": _GCC13,
    "llvm15": _CLANG15,
    "llvm16": _CLANG16,
}

# -- To switch between gcc/clang

string_flag(
    name = "compiler",
    build_setting_default = "gcc",
    values = [key for key, value in AVAILABLE_COMPILERS.items()]
)
config_setting(name = "compiler_gcc", flag_values = {":compiler": "gcc"})
config_setting(name = "compiler_gcc12", flag_values = {":compiler": "gcc12"})
config_setting(name = "compiler_gcc13", flag_values = {":compiler": "gcc13"})
config_setting(name = "compiler_llvm15", flag_values = {":compiler": "llvm15"})
config_setting(name = "compiler_llvm16", flag_values = {":compiler": "llvm16"})

# -- System toolchain

make_toolchain_from_install_root(
    install_root = "/usr",
    additional_args = COMPILE_LINK_FLAGS,
)

# -- Gcc

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_ROOT + "/" + _GCC12,
    additional_args = COMPILE_LINK_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_ROOT + "/" + _GCC13,
    additional_args = COMPILE_LINK_FLAGS,
)

# -- Llvm

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_ROOT + "/" + _CLANG15,
    additional_args = COMPILE_LINK_FLAGS,
)

make_toolchain_from_install_root(
    install_root = _TOOLCHAIN_ROOT + "/" + _CLANG16,
    additional_args = COMPILE_LINK_FLAGS,
)

# -- Clang Tidy

binary_alias(
    name = "clangtidy_bin",
    src = select({        
        ":compiler_llvm15": _TOOLCHAIN_ROOT + "/" + _CLANG15 + "/bin/clang-tidy",
        ":compiler_llvm16": _TOOLCHAIN_ROOT + "/" + _CLANG16 + "/bin/clang-tidy",
        "//conditions:default": _TOOLCHAIN_ROOT + "/" + _CLANG + "/bin/clang-tidy",
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
        ":compiler_gcc12": ":" + _GCC12,
        ":compiler_gcc13": ":" + _GCC13,
        ":compiler_llvm15": ":" + _CLANG15,
        ":compiler_llvm16": ":" + _CLANG16,
        "//conditions:default": ":gcc",
    }),
)


