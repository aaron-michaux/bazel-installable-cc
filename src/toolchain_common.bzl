"""
Configuration for 'gcc' and 'clang' compilers on Ubuntu
"""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "feature",
    "feature_set",
    "flag_group",
    "flag_set",
    "tool",
    "tool_path",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:defs.bzl", "cc_toolchain")

ALL_ACTIONS = [
    # Assembler actions
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.assemble,

    # Compiler
    ACTION_NAMES.cc_flags_make_variable, # Propagates CC_FLAGS to genrules
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,

    # Link
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
    ACTION_NAMES.cpp_link_executable,

    # AR
    ACTION_NAMES.cpp_link_static_library,

    # LTO
    ACTION_NAMES.lto_backend,
    ACTION_NAMES.lto_indexing,
    ACTION_NAMES.lto_index_for_executable,
    ACTION_NAMES.lto_index_for_dynamic_library,
    ACTION_NAMES.lto_index_for_nodeps_dynamic_library,
]

ALL_COMPILE_ACTIONS = [
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.assemble,
    ACTION_NAMES.cc_flags_make_variable, # Propagates CC_FLAGS to genrules
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
]

ALL_C_COMPILE_ACTIONS = [
    ACTION_NAMES.c_compile,
]

ALL_CPP_COMPILE_ACTIONS = [
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.assemble,
    ACTION_NAMES.cc_flags_make_variable, # Propagates CC_FLAGS to genrules
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
]

PREPROCESSOR_COMPILE_ACTIONS = [
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.assemble,
]


ALL_LINK_ACTIONS = [
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
    ACTION_NAMES.cpp_link_executable,
    ACTION_NAMES.cpp_link_static_library,
]

LTO_INDEX_ACTIONS = [
    ACTION_NAMES.lto_backend,
    ACTION_NAMES.lto_indexing,
    ACTION_NAMES.lto_index_for_executable,
    ACTION_NAMES.lto_index_for_dynamic_library,
    ACTION_NAMES.lto_index_for_nodeps_dynamic_library,
]

def default_flagsets(ctx):
    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.base_compile_flags)] if ctx.attr.base_compile_flags else []),
        ),
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.dbg_compile_flags)] if ctx.attr.dbg_compile_flags else []),
            with_features = [with_feature_set(features = ["dbg"])],
        ),
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.opt_compile_flags)] if ctx.attr.opt_compile_flags else []),
            with_features = [with_feature_set(features = ["opt"])],
        ),
        flag_set(
            actions = ALL_COMPILE_ACTIONS + [ACTION_NAMES.lto_backend],
            flag_groups = ([flag_group(flags = ctx.attr.cxx_flags)] if ctx.attr.cxx_flags else []),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.base_link_flags)] if ctx.attr.base_link_flags else []),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.dbg_link_flags)] if ctx.attr.dbg_link_flags else []),
            with_features = [with_feature_set(features = ["dbg"])],
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.opt_link_flags)] if ctx.attr.opt_link_flags else []),
            with_features = [with_feature_set(features = ["opt"])],
        ),
    ]

def default_warnings(ctx):
    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.warning_flags)] if ctx.attr.warning_flags else []),
        ),
    ]

def warning_error_flags(ctx):
    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ["-Werror"])]),
        ),
    ]

def stdcxx_flags(ctx):

    install_root = ctx.attr.install_root if ctx.attr.install_root else "/usr"
    
    link_flags = ["-lstdc++", "-lm"]
    if ctx.attr.install_root and ctx.attr.install_root != "/usr":
        link_flags += [
            "-Wl,-rpath," + install_root + "/lib64",
        ]
    
    return [
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = link_flags)]),
            with_features = [with_feature_set(features = [], not_features = ["libcxx"])],
        ),
    ]

def libcxx_flags(ctx):
    """
    Generate libcxx flags for the given compiler context

    Args:
      ctx: The compiler context

    Returns:
      flagset suitable for a compiler 'feature'
    """
    if ctx.attr.compiler != "gcc" and ctx.attr.compiler != "clang":
        fail("invalid compiler")

    system_llvm_root = "/opt/local/llvm"
    install_root = system_llvm_root if ctx.attr.compiler == "gcc" else (ctx.attr.install_root if ctx.attr.install_root else "/usr")

    architecture = ctx.attr.architecture if ctx.attr.architecture else "x86_64-linux-gnu"
    
    #    print ("INSTALL_ROOT", install_root)
    
    return [
        flag_set(
            actions = ALL_CPP_COMPILE_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = [
                        "-nostdinc++",
                        "-isystem" + install_root + "/include/c++/v1",
                        "-isystem" + install_root + "/include/" + architecture + "/c++/v1",
                    ],
                ),
            ],
            with_features = [with_feature_set(features = [], not_features = ["stdcxx"])],
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = (["-nostdlib++"] if ctx.attr.compiler == "clang" else []) + [
                        "-L" + install_root + "/lib",
                        "-L" + install_root + "/lib" + architecture,
                        "-lc++",
                        "-lm",
                        "-Wl,-rpath," + install_root + "/lib/" + architecture,
                    ],
                ),
            ],
            with_features = [with_feature_set(features = [], not_features = ["stdcxx"])],
        ),
    ]

def asan_flags(ctx):
    """
    Generate asan flags for the given compiler context

    Args:
      ctx: The compiler context

    Returns:
      flagset suitable for a compiler 'feature'
    """
    if ctx.attr.compiler != "gcc" and ctx.attr.compiler != "clang":
        fail("invalid compiler")
    is_gcc = (ctx.attr.compiler == "gcc")

    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(
                flags = (["-fno-optimize-sibling-calls"] if is_gcc else []) + [
                    "-O0",
                    "-g",
                    "-fno-omit-frame-pointer",
                    "-fsanitize=address",
                ],
            )]),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS,
            flag_groups = ([flag_group(
                flags = (["-static-libasan"] if is_gcc else []) + [
                    "-fsanitize=address",
                ],
            )]),
        ),
    ]

def usan_flags(ctx):
    """
    Generate usan flags for the given compiler context

    Args:
      ctx: The compiler context

    Returns:
      flagset suitable for a compiler 'feature'
    """

    if ctx.attr.compiler != "gcc" and ctx.attr.compiler != "clang":
        fail("invalid compiler")
    is_gcc = (ctx.attr.compiler == "gcc")
    is_clang = (ctx.attr.compiler == "clang")    

    # Have to convince bazel not to set gcc rt library
    # @see https://bugs.llvm.org/show_bug.cgi?id=16404
    _CLANG_EXTRA = [flag_set(
        actions = ALL_COMPILE_ACTIONS,
        flag_groups = [flag_group(flags = ["--rtlib=compiler-rt"])],
        with_features = [with_feature_set(features = ["stdcxx"])],
    )]

    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(
                flags = ([] if is_gcc else []) + [
                    "-g",
                    "-fno-optimize-sibling-calls",
                    "-fno-omit-frame-pointer",
                    "-fsanitize=undefined",
                ],
            )]),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS,
            flag_groups = ([flag_group(
                flags = ["-fsanitize=undefined"] +
                        (["-static-libubsan"] if is_gcc else ["-lubsan"]),  # clang
            )]),
        ),
    ] + (_CLANG_EXTRA if is_clang else [])

def tsan_flags(ctx):
    """
    Generate tsan flags for the given compiler context

    Args:
      ctx: The compiler context

    Returns:
      flagset suitable for a compiler 'feature'
    """
    if ctx.attr.compiler != "gcc" and ctx.attr.compiler != "clang":
        fail("invalid compiler")
    is_gcc = (ctx.attr.compiler == "gcc")
    is_clang = (ctx.attr.compiler == "clang")

    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(
                flags = [
                    "-O0",
                    "-g",
                    "-fno-optimize-sibling-calls",
                    "-fno-omit-frame-pointer",
                    "-fsanitize=thread",
                ],
            )]),
        ),
        flag_set(
            actions = [ACTION_NAMES.cpp_link_executable],
            flag_groups = ([flag_group(
                flags = (["-static-libtsan"] if is_gcc else []) + [
                    "-pie",
                    "-fsanitize=thread",
                ],
            )]),
        ),
        flag_set(
            actions = [
                ACTION_NAMES.cpp_link_dynamic_library,
                ACTION_NAMES.cpp_link_nodeps_dynamic_library,
            ],
            flag_groups = ([flag_group(
                flags = (["-static-libtsan"] if is_gcc else []) + [
                    "-fsanitize=thread",
                ],
            )]),
        ),
    ]

def toolchain_benchmark_flags(ctx):
    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.benchmark_compile_flags)] if ctx.attr.benchmark_compile_flags else []),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.benchmark_link_flags)] if ctx.attr.benchmark_link_flags else []),
        ),
    ]

def lto_flags(ctx):
    """
    Generate lto flags for the given compiler context

    Args:
      ctx: The compiler context

    Returns:
      flagset suitable for a compiler 'feature'
    """
    _LTO_GCC_FLAGS = [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = [
                "-flto",
                "-ffat-lto-objects",
            ])]),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = [
                "-flto",
                "-fuse-linker-plugin",
            ])]),
        ),
    ]
    _LTO_CLANG_FLAGS = [
        flag_set(
            actions = [ACTION_NAMES.c_compile, ACTION_NAMES.cpp_compile],
            flag_groups = ([flag_group(flags = ["-flto=thin"])]),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = ["-flto=thin"])]),
        ),
    ]
    if ctx.attr.compiler == "gcc":
        return _LTO_GCC_FLAGS
    if ctx.attr.compiler == "clang":
        return _LTO_CLANG_FLAGS
    fail("invalid compiler")

def unfiltered_compile_flags(ctx):
    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ctx.attr.unfiltered_compile_flags)] if ctx.attr.unfiltered_compile_flags else []),
        ),
    ]

def pic_flags(ctx):
    return [
        flag_set(
            actions = [
                ACTION_NAMES.assemble,
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.linkstamp_compile,
                ACTION_NAMES.c_compile,
                ACTION_NAMES.cpp_compile,
                ACTION_NAMES.cpp_module_codegen,
                ACTION_NAMES.cpp_module_compile,
            ],
            flag_groups = [flag_group(flags = ["-fPIC"])],
        ),
    ]

def gold_linker_flags(ctx):
    return [
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = ["-fuse-ld=gold"])]),
            with_features = [with_feature_set(
                not_features = ["lld_linker", "toolchain_linker"],
            )],
        ),
    ]

def lld_linker_flags(ctx):
    return [
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = ["-fuse-ld=lld"])]),
            with_features = [with_feature_set(
                not_features = ["gold_linker", "toolchain_linker"],
            )],
        ),
    ]

def toolchain_linker_flags(ctx):
    return [
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([flag_group(flags = ["-fuse-ld=gold"])] if ctx.attr.compiler == "gcc" else [flag_group(flags = ["-fuse-ld=lld"])]),
            with_features = [with_feature_set(
                not_features = ["lld_linker", "gold_linker"],
            )],
        ),
    ]

def shared_flags(ctx):
    return [
        flag_set(
            actions = [
                ACTION_NAMES.cpp_link_dynamic_library,
                ACTION_NAMES.cpp_link_nodeps_dynamic_library,
                ACTION_NAMES.lto_index_for_dynamic_library,
                ACTION_NAMES.lto_index_for_nodeps_dynamic_library,
            ],
            flag_groups = [flag_group(flags = ["-shared"])],
        ),
    ]

def no_canonical_system_headers_flags(ctx):
    """
    The flag-set for '-fno-canonical-system-headers' in gcc only; no effect calling with clang.

    Args:
      ctx: The compiler context

    Returns:
      flagset suitable for a compiler 'feature'
    """
    if ctx.attr.compiler == "gcc":
        return [
            flag_set(
                actions = ALL_COMPILE_ACTIONS,
                flag_groups = ([flag_group(flags = ["-fno-canonical-system-headers"])]),
            ),
        ]
    if ctx.attr.compiler == "clang":
        return []  # Not a feature (not necessary) in clang
    fail("invalid compiler")

def runtime_library_search_flags(ctx):
    return [
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = [
                flag_group(
                    iterate_over = "runtime_library_search_directories",
                    flag_groups = [
                        flag_group(
                            flags = [
                                "-Wl,-rpath,$EXEC_ORIGIN/%{runtime_library_search_directories}",
                            ],
                            expand_if_true = "is_cc_test",
                        ),
                        flag_group(
                            flags = [
                                "-Wl,-rpath,$ORIGIN/%{runtime_library_search_directories}",
                            ],
                            expand_if_false = "is_cc_test",
                        ),
                    ],
                    expand_if_available =
                        "runtime_library_search_directories",
                ),
            ],
            with_features = [
                with_feature_set(features = ["static_link_cpp_runtimes"]),
            ],
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = [
                flag_group(
                    iterate_over = "runtime_library_search_directories",
                    flag_groups = [
                        flag_group(
                            flags = [
                                "-Wl,-rpath,$ORIGIN/%{runtime_library_search_directories}",
                            ],
                        ),
                    ],
                    expand_if_available =
                        "runtime_library_search_directories",
                ),
            ],
            with_features = [
                with_feature_set(
                    not_features = ["static_link_cpp_runtimes"],
                ),
            ],
        ),
    ]

def llvm_coverage_map_format_flags(ctx):
    return [
        flag_set(
            actions = [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.c_compile,
                ACTION_NAMES.cpp_compile,
                ACTION_NAMES.cpp_module_compile,
                ACTION_NAMES.objc_compile,
                ACTION_NAMES.objcpp_compile,
            ],
            flag_groups = [
                flag_group(
                    flags = [
                        "-fprofile-instr-generate",
                        "-fcoverage-mapping",
                        "-fno-elide-constructors",
                        "-fno-inline",
                    ],
                ),
            ],
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS + [
                "objc-executable",
                "objc++-executable",
            ],
            flag_groups = [
                flag_group(flags = ["-fprofile-instr-generate"]),
            ],
        ),
    ]

def gcc_coverage_map_format_flags(ctx):
    return [
        flag_set(
            actions = [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.c_compile,
                ACTION_NAMES.cpp_compile,
                ACTION_NAMES.cpp_module_compile,
                ACTION_NAMES.objc_compile,
                ACTION_NAMES.objcpp_compile,
                "objc-executable",
                "objc++-executable",
            ],
            flag_groups = [
                flag_group(
                    flags = [
                        "--coverage",
                        "-fprofile-arcs",
                        "-ftest-coverage",
                        "-fno-elide-constructors",
                        "-fno-inline",
                        "-fno-default-inline",
                    ],
                    expand_if_available = "gcov_gcno_file",
                ),
            ],
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = [flag_group(flags = ["--coverage"])],
        ),
    ]

def coverage_flags(ctx):
    if ctx.attr.compiler != "gcc" and ctx.attr.compiler != "clang":
        fail("invalid compiler")
    toolchain_flags = llvm_coverage_map_format_flags(ctx) if ctx.attr.compiler == "clang" else gcc_coverage_map_format_flags(ctx)

    return toolchain_flags + [
        flag_set(
            actions = [
                ACTION_NAMES.preprocess_assemble,
                ACTION_NAMES.c_compile,
                ACTION_NAMES.cpp_compile,
                ACTION_NAMES.cpp_header_parsing,
                ACTION_NAMES.cpp_module_compile,
            ],
            flag_groups = ([
                flag_group(flags = ctx.attr.coverage_compile_flags),
            ] if ctx.attr.coverage_compile_flags else []),
        ),
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = ([
                flag_group(flags = ctx.attr.coverage_link_flags),
            ] if ctx.attr.coverage_link_flags else []),
        ),
    ]

def strip_debug_symbols_flags(ctx):
    return [
        flag_set(
            actions = ALL_LINK_ACTIONS + LTO_INDEX_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = ["-Wl,-S"],
                    expand_if_available = "strip_debug_symbols",
                ),
            ],
        ),
    ]

def make_base_features(ctx):
    return [
        # TODO stdcxx => stdcxx

        feature(name = "defaults", enabled = True, flag_sets = default_flagsets(ctx)),
        feature(name = "stdcxx", enabled = True, flag_sets = stdcxx_flags(ctx)),
        feature(name = "libcxx", enabled = False, flag_sets = libcxx_flags(ctx)),
        feature(name = "shared_flag", flag_sets = shared_flags(ctx)),
        feature(name = "asan", enabled = False, flag_sets = asan_flags(ctx)),
        feature(name = "usan", enabled = False, flag_sets = usan_flags(ctx)),
        feature(name = "ubsan", enabled = False, flag_sets = usan_flags(ctx)),
        feature(name = "tsan", enabled = False, flag_sets = tsan_flags(ctx), implies = ["pic"]),
        feature(name = "lto", enabled = False, flag_sets = lto_flags(ctx), implies = ["toolchain_linker"]),
        feature(name = "pic", enabled = False, flag_sets = pic_flags(ctx)),
        feature(name = "warnings", enabled = False, flag_sets = default_warnings(ctx)),
        feature(name = "warn_error", enabled = False, flag_sets = warning_error_flags(ctx)),
        feature(name = "gold_linker", enabled = False, flag_sets = gold_linker_flags(ctx)),
        feature(name = "lld_linker", enabled = False, flag_sets = lld_linker_flags(ctx)),
        feature(name = "toolchain_linker", enabled = True, flag_sets = toolchain_linker_flags(ctx)),
        feature(name = "supports_pic", enabled = True),
        feature(name = "supports_start_end_lib", enabled = True),
        feature(name = "dbg"),
        feature(name = "opt"),
        feature(name = "benchmark", enabled = False, flag_sets = toolchain_benchmark_flags(ctx)),
        feature(
            name = "no_canonical_system_headers",
            enabled = True,
            flag_sets = no_canonical_system_headers_flags(ctx),
        ),
        feature(
            name = "runtime_library_search_directories_feature",
            enabled = True,
            flag_sets = runtime_library_search_flags(ctx),
        ),
        feature(
            name = "unfiltered_compile_flags",
            enabled = False,
            flag_sets = unfiltered_compile_flags(ctx),
        ),
        feature(
            name = "coverage",
            flag_sets = coverage_flags(ctx),
            provides = ["profile"],
        ),
        feature(
            name = "strip_debug_symbols",
            flag_sets = strip_debug_symbols_flags(ctx),
        )
    ]

def calculate_toolchain_paths(ctx):
    """
    Calculates the toolchain paths as specified by the compiler context

    Args:
      ctx: The compiler context

    Returns:
      A list of 'tool_path' for a 'gcc' or 'clang' compiler
    """

    if ctx.attr.compiler != "gcc" and ctx.attr.compiler != "clang":
        fail("invalid compiler")
    if ctx.attr.tool_paths:
        return ctx.attr.tool_paths

    install_root = ctx.attr.install_root if ctx.attr.install_root else "/usr"
    bindir = "bin"
    prefix = ctx.attr.prefix if ctx.attr.prefix else ""
    suffix = ctx.attr.suffix if ctx.attr.suffix else ""
    
    base_path = install_root + "/" + bindir + "/" + prefix
    if ctx.attr.compiler == "gcc":
        # gcc
        return [
            tool_path(name = "ar", path = base_path + "gcc-ar" + suffix),
            tool_path(name = "cpp", path = base_path + "g++" + suffix),
            tool_path(name = "dwp", path = base_path + "dwp" + suffix),
            tool_path(name = "gcc", path = base_path + "gcc" + suffix),
            tool_path(name = "gcov", path = base_path + "gcov" + suffix),
            tool_path(name = "ld", path = base_path + "ld" + suffix),
            tool_path(name = "nm", path = base_path + "gcc-nm" + suffix),
            tool_path(name = "objcopy", path = base_path + "objcopy" + suffix),
            tool_path(name = "objdump", path = base_path + "objdump" + suffix),
            tool_path(name = "strip", path = base_path + "strip" + suffix),
            tool_path(name = "compat-ld", path = "/bin/false"),
        ]

    # Clang
    return [
        tool_path(name = "ar", path = base_path + "llvm-ar" + suffix),
        tool_path(name = "cpp", path = base_path + "clang++" + suffix),
        tool_path(name = "dwp", path = base_path + "llvm-dwp" + suffix),
        tool_path(name = "gcc", path = base_path + "clang" + suffix),
        tool_path(name = "gcov", path = "/bin/false"),
        tool_path(name = "ld", path = base_path + "lld" + suffix),
        tool_path(name = "nm", path = base_path + "llvm-nm" + suffix),
        tool_path(name = "objcopy", path = base_path + "llvm-objcopy" + suffix),
        tool_path(name = "objdump", path = base_path + "llvm-objdump" + suffix),
        tool_path(name = "strip", path = base_path + "llvm-strip" + suffix),
        tool_path(name = "compat-ld", path = "/bin/false"),
    ]

COMMON_ATTRIBUTES = {
    "cpu": attr.string(mandatory = True),
    "compiler": attr.string(mandatory = True),
    "version": attr.string(mandatory = False),  # The compiler version for directory includes
    "install_root": attr.string(mandatory = True),  # install root of compiler
    "prefix": attr.string(mandatory = False),  # prefix prepended before tool name
    "suffix": attr.string(mandatory = False),  # suffix appended to tools, like "-9" for "gcc-9"
    "architecture": attr.string(mandatory = True), # 'x86_64-linux-gnu' etc
    "toolchain_identifier": attr.string(mandatory = True),
    "host_system_name": attr.string(mandatory = True),
    "target_system_name": attr.string(mandatory = True),
    "target_libc": attr.string(mandatory = True),
    "abi_version": attr.string(mandatory = True),
    "abi_libc_version": attr.string(mandatory = True),
    "cxx_builtin_include_directories": attr.string_list(mandatory = True),
    "tool_paths": attr.string_dict(),
    "base_compile_flags": attr.string_list(mandatory = True),
    "dbg_compile_flags": attr.string_list(mandatory = True),
    "opt_compile_flags": attr.string_list(mandatory = True),
    "benchmark_compile_flags": attr.string_list(),
    "cxx_flags": attr.string_list(),
    "base_link_flags": attr.string_list(mandatory = True),
    "dbg_link_flags": attr.string_list(mandatory = True),
    "opt_link_flags": attr.string_list(mandatory = True),
    "extra_include_directories": attr.string_list(),
    "benchmark_link_flags": attr.string_list(),
    "link_libs": attr.string_list(),
    "warning_flags": attr.string_list(),  # For the feature: --features=warnings
    "unfiltered_compile_flags": attr.string_list(),
    "coverage_compile_flags": attr.string_list(),
    "coverage_link_flags": attr.string_list(),
    "supports_start_end_lib": attr.bool(),
    "builtin_sysroot": attr.string(),
}

def _impl(ctx):
    tool_paths = calculate_toolchain_paths(ctx)
    extra_inc_dirs = ctx.attr.extra_include_directories if ctx.attr.extra_include_directories else []
    build_inc_dirs = ctx.attr.cxx_builtin_include_directories + extra_inc_dirs    
    return [
        cc_common.create_cc_toolchain_config_info(
            ctx = ctx,
            target_cpu = ctx.attr.cpu,  # "linux_x86_64",
            compiler = ctx.attr.compiler,
            toolchain_identifier = ctx.attr.toolchain_identifier,
            host_system_name = ctx.attr.host_system_name,
            target_system_name = ctx.attr.target_system_name,
            target_libc = ctx.attr.target_libc,
            abi_version = ctx.attr.abi_version,
            abi_libc_version = ctx.attr.abi_libc_version,
            tool_paths = tool_paths,
            features = make_base_features(ctx),
            cxx_builtin_include_directories = build_inc_dirs,
        )]

unix_toolchain_config = rule(
    implementation = _impl,
    attrs = COMMON_ATTRIBUTES,
    provides = [DefaultInfo, CcToolchainConfigInfo],
)

#
# -- Convenience macros for getting toolchain cxx include directories
#

def calculate_gcc_include_directories(gcc_installation_path, architecture, version):
    # architecture: x86_64-linux-gnu, x86_64-pc-linux-gnu, x86_64-buildroot-linux-gnu
    major_version = version.split(".")[0]
    def with_version(version):
        return [
            "lib/gcc/" + architecture + "/" + version + "/include",  #      Ubuntu package
            "lib/gcc/" + architecture + "/" + version + "/include-fixed",  # Ubuntu package
            "include/c++/" + version,
            "include/" + architecture + "/c++/" + version,  # Ubuntu package
            "include/c++/" + version + "/c/backward",
        ]

    paths = with_version(version) + with_version(major_version)        
    return [gcc_installation_path + "/" + x for x in paths]

def calculate_clang_include_directories(clang_installation_path, architecture, version):
    major_version = version.split(".")[0]
    def with_version(version):
        return [
            "lib/clang/" + version + "/include",
            "lib/clang/" + version + "/share",  # asan blacklist etc.
        ]
    paths = [
        "include/c++/v1",
        "include/" + architecture + "/c++/v1"
    ] + with_version(version) + with_version(major_version)
    
    return [clang_installation_path + "/" + x for x in paths]

def compiler_default_directories(compiler, install_root, architecture, version):
    """
    Calculate the default (builtin) c++ system header directories

    Args:
      compiler: should be 'gcc' or 'clang'
      prefix: the install root prefix for the toolchain; tool is at, eg, {prefix}/bin/gcc-9
      version: the tool version string used to locate c++ headers

    Returns:
      flagset suitable for a compiler 'feature'
    """
    base_directories = [
        "/usr/include/" + architecture,
        "/usr/include",
    ]
    if compiler == "gcc":
        return base_directories + calculate_gcc_include_directories(install_root, architecture, version)
    elif compiler == "clang":
        return base_directories + calculate_clang_include_directories(install_root, architecture, version)
    fail("invalid compiler")

#
# -- Convenience macros for specifying a 'gcc' or 'clang' toolchain and toolchain config
#
       
def make_toolchain_config(
        name,
        compiler,
        cpu = "k8",
        version = None,
        install_root = "/usr",
        prefix = "",
        suffix = None,
        architecture = "x86_64-linux-gnu",
        toolchain_identifier = None,
        supports_start_end_lib = True,
        cxx_builtin_include_directories = None,
        extra_include_directories = None,
        host_system_name = "local",
        target_system_name = "local",
        target_libc = "local",
        abi_version = "local",
        abi_libc_version = "local",
        additional_args = {},
        **kargs):
    """
    Make a 'unix_toolchain_config' with defauts.

    Args:
      name: identifier
      compiler: Must be 'gcc' or 'clang'
      cpu: Defaults to 'k8'
      version: For finding installation includes/libraries
      prefix: Prefix to find installation root
      suffix: Suffix added to certain toolchain programs
      supports_start_end_lib: Boolean that tells bazel to skip building static libraries if possible
      cxx_builtin_include_directories: C++ system include directories; Pass 'None' for defaults
      extra_include_directories: C++ include directories to add builtin include directories
      toolchain_identifier: Default is 'local_gcc' or 'local_clang'
      host_system_name: Defaults to 'local'
      target_system_name: Default to 'local'
      target_libc: Default 'local'
      abi_version: Default 'local'
      abi_libc_version: Default 'local
      additional_args: A dictionary of additional arguments, to be expanded into kargs; default {}
      **kargs: Arguments passed straight through to the 'unix_toolchain_config'
    """

    if compiler != "gcc" and compiler != "clang":
        fail("invalid compiler")
        
    if not toolchain_identifier:
        toolchain_identifier = "local_" + compiler + \
                               ("_" + version if version else "")
        
    # Calculate the include directories
    if not cxx_builtin_include_directories:
        cxx_builtin_include_directories = compiler_default_directories(compiler, install_root, architecture, version)

    # In the call below to `unix_toolchain_config`, we unpack **kargs.
    # This will throw an error if `kargs` wants to override any of the other
    # arguments. So we collate all arguments together directly in kargs.
    
    final_kargs = kargs
    
    def update_dict(d, key = None, value = None):
        # Disable check, which erroneously fires because for loops
        # below can be empty
        # buildifier: disable=uninitialized
        if not key in d:
            d[key] = value

    for key, value in additional_args.items():
        update_dict(final_kargs, key, value)

    update_dict(final_kargs, "name", name)
    update_dict(final_kargs, "cpu", cpu)
    update_dict(final_kargs, "compiler", compiler)
    update_dict(final_kargs, "version", version)
    update_dict(final_kargs, "install_root", install_root)
    update_dict(final_kargs, "prefix", prefix)
    update_dict(final_kargs, "suffix", suffix)
    update_dict(final_kargs, "architecture", architecture)
    update_dict(final_kargs, "toolchain_identifier", toolchain_identifier)
    update_dict(final_kargs, "host_system_name", host_system_name)
    update_dict(final_kargs, "target_system_name", target_system_name)
    update_dict(final_kargs, "target_libc", target_libc)
    update_dict(final_kargs, "abi_version", abi_version)
    update_dict(final_kargs, "abi_libc_version", abi_libc_version)
    update_dict(final_kargs, "supports_start_end_lib", supports_start_end_lib)
    update_dict(final_kargs, "cxx_builtin_include_directories", cxx_builtin_include_directories)
    update_dict(final_kargs, "extra_include_directories", extra_include_directories)

    unix_toolchain_config(**final_kargs)
    
def make_toolchain(name, toolchain_config):
    cc_toolchain(
        name = name + "_cc_toolchain",
        all_files = ":compiler_deps",
        compiler_files = ":compiler_deps",
        dwp_files = ":empty",
        linker_files = ":compiler_deps",
        objcopy_files = ":empty",
        strip_files = ":compiler_deps",
        supports_param_files = 0,
        toolchain_config = toolchain_config,
    )
    
    native.toolchain(
        name = name,
        exec_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",            
        ],
        target_compatible_with = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",            
        ],
        toolchain = ":" + name + "_cc_toolchain",
        toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
    )
    

def make_toolchain_from_install_root(name, install_root, additional_args,
                                     sys_machine, host_cxx_builtin_dirs,
                                     is_default):
    """
    Logic to deduce toolchain parameters from install_root only
    """
    label = name
    config_label = label + "_config"
    version = None
    
    if is_default:
        make_toolchain_config(
            name = config_label,
            compiler = "gcc",
            install_root = "/usr",
            architecture = sys_machine,
            additional_args = additional_args,
            cxx_builtin_include_directories = host_cxx_builtin_dirs,
        )
    else:               
        basename = install_root.split("/")[-1]
        is_gcc = basename.startswith("gcc")
        parts = basename.split("-")
        is_clang = (parts[0] == "llvm")
        is_gcc = parts[0] == "gcc"
        if len(parts) < 2 or (not is_clang and not is_gcc):
            fail("could not deduce clang/gcc from install_root: {}".format(install_root))
            return None
        version = parts[1]
        major_version = version.split(".")[0]
        architecture = "x86_64-pc-linux-gnu" if is_gcc else "x86_64-unknown-linux-gnu"
        suffix = ("-" + major_version) if is_gcc else ""
        config_label = label + "_config"    
        make_toolchain_config(
            name = config_label,
            compiler = "gcc" if is_gcc else "clang",
            version = version,
            install_root = install_root,
            architecture = architecture,
            suffix = suffix,
            additional_args = additional_args,
        )
    
    make_toolchain(
        name = label,
        toolchain_config = ":" + config_label,        
    )
        
# -- binary alias

def binary_alias_impl_(ctx):
    out = ctx.actions.declare_file(ctx.label.name)    
    ctx.actions.write(
        output = out,
        content = "#!/bin/bash\n{} \"$@\"\n".format(ctx.attr.src),
        is_executable = True,
    )
    return [DefaultInfo(files = depset([out]), executable = out)]

binary_alias = rule(
    implementation = binary_alias_impl_,
    executable = True, # You can do 'bazel run' on this rule
    attrs = {
        "src": attr.string()
    },
)
