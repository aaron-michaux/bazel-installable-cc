"""
Configuration for 'gcc' and 'clang' compilers on Ubuntu
"""

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "feature",
    "flag_group",
    "flag_set",
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
    ACTION_NAMES.cc_flags_make_variable,  # Propagates CC_FLAGS to genrules
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
    ACTION_NAMES.cc_flags_make_variable,  # Propagates CC_FLAGS to genrules
    ACTION_NAMES.c_compile,
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
]

PREPROCESSOR_COMPILE_ACTIONS = [
    ACTION_NAMES.preprocess_assemble,
    ACTION_NAMES.assemble,
]

ALL_C_COMPILE_ACTIONS = [
    ACTION_NAMES.c_compile,
]

ALL_CPP_COMPILE_ACTIONS = [
    ACTION_NAMES.cc_flags_make_variable,  # Propagates CC_FLAGS to genrules
    ACTION_NAMES.cpp_compile,
    ACTION_NAMES.cpp_header_parsing,
]

LINK_ACTIONS = [
    ACTION_NAMES.cpp_link_dynamic_library,
    ACTION_NAMES.cpp_link_nodeps_dynamic_library,
    ACTION_NAMES.cpp_link_executable,
]

STATIC_LINK_ACTIONS = [
    ACTION_NAMES.cpp_link_static_library,
]

LTO_INDEX_ACTIONS = [
    ACTION_NAMES.lto_backend,
    ACTION_NAMES.lto_indexing,
    ACTION_NAMES.lto_index_for_executable,
    ACTION_NAMES.lto_index_for_dynamic_library,
    ACTION_NAMES.lto_index_for_nodeps_dynamic_library,
]

ALL_NON_STATIC_LINK_ACTIONS = LINK_ACTIONS + LTO_INDEX_ACTIONS
ALL_LINK_ACTIONS = STATIC_LINK_ACTIONS + ALL_NON_STATIC_LINK_ACTIONS

def combine_flags(set1, set2):
    """Combine two lists of flags, remove duplicates from 2nd.

    Args:
      set1: 1st list of strings.
      set2: 2nd list of strings.

    Returns:
      The combined set.
    """
    if not set2:
        return set1
    flags = set1 + [x for x in set2 if x not in set1]
    return flags

def make_flagset(actions, flags, features = None):
    """Flagset factory for given actions and flags|features.

    Args:
      actions: The actions the flagset applies to.
      flags: The list of flags; can be empty.
      features: If set, the "with_feature_set" features.

    Returns:
      A `flag_set`, or None if no `flags` given.
    """
    if len(flags) == 0:
        return None
    if features:
        return flag_set(
            actions = actions,
            flag_groups = [flag_group(flags = flags)],
            with_features = [with_feature_set(features = features)],
        )
    return flag_set(actions = actions, flag_groups = ([flag_group(flags = flags)]))

# buildifier: disable=function-docstring
def default_flagsets(ctx):
    # Compile flags
    base_comp_flags = combine_flags([], ctx.attr.base_compile_flags)
    c_flags = combine_flags([], ctx.attr.c_flags)
    cxx_flags = combine_flags([], ctx.attr.cxx_flags)
    dbg_comp_flags = combine_flags(["-O0", "-g"], ctx.attr.dbg_compile_flags)
    opt_comp_flags = combine_flags(
        ["-O3", "-DNDEBUG", "-ffunction-sections", "-fdata-sections"],
        ctx.attr.opt_compile_flags,
    )
    coverage_comp_flags = combine_flags([], ctx.attr.coverage_compile_flags)
    benchmark_comp_flags = combine_flags(
        ["-O3", "-g", "-fno-omit-frame-pointer"],
        ctx.attr.benchmark_compile_flags,
    )

    # Link flags
    base_link_flags = combine_flags([], ctx.attr.base_link_flags)
    dbg_link_flags = combine_flags(["-g", "-Wl,-no-as-needed"], ctx.attr.dbg_link_flags)
    opt_link_flags = combine_flags(["-Wl,--gc-sections"], ctx.attr.opt_link_flags)
    coverage_link_flags = combine_flags([], ctx.attr.coverage_link_flags)
    benchmark_link_flags = combine_flags(["-Wl,-z,now"], ctx.attr.benchmark_link_flags)

    # Build `flagsets`
    flagsets = [
        # Compiler
        make_flagset(ALL_COMPILE_ACTIONS, base_comp_flags),
        make_flagset(ALL_C_COMPILE_ACTIONS, c_flags),
        make_flagset(ALL_CPP_COMPILE_ACTIONS, cxx_flags),
        make_flagset(ALL_COMPILE_ACTIONS, dbg_comp_flags, ["dbg"]),
        make_flagset(ALL_COMPILE_ACTIONS, opt_comp_flags, ["opt"]),
        make_flagset(ALL_COMPILE_ACTIONS, benchmark_comp_flags, ["benchmark"]),
        make_flagset(ALL_COMPILE_ACTIONS, coverage_comp_flags, ["coverage"]),
        # Linker
        make_flagset(ALL_NON_STATIC_LINK_ACTIONS, base_link_flags),
        make_flagset(ALL_NON_STATIC_LINK_ACTIONS, dbg_link_flags, ["dbg"]),
        make_flagset(ALL_NON_STATIC_LINK_ACTIONS, opt_link_flags, ["opt"]),
        make_flagset(ALL_NON_STATIC_LINK_ACTIONS, coverage_link_flags, ["coverage"]),
        make_flagset(ALL_NON_STATIC_LINK_ACTIONS, benchmark_link_flags, ["benchmark"]),
    ]

    return [x for x in flagsets if x]  # Filter out 'None' flagsets

# buildifier: disable=function-docstring
def warning_flags(ctx):
    flags = combine_flags(["-Wall"], ctx.attr.warning_flags)
    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = flags)]),
        ),
    ]

# buildifier: disable=function-docstring
def warning_error_flags(ctx):
    return [
        flag_set(
            actions = ALL_COMPILE_ACTIONS,
            flag_groups = ([flag_group(flags = ["-Werror"])]),
        ),
    ]

# buildifier: disable=function-docstring
def default_stdlib_flags(ctx):
    install_root = ctx.attr.install_root
    has_libcxx = "libcxx" in ctx.features
    has_stdcxx = "stdcxx" in ctx.features
    if has_libcxx or has_stdcxx:
        return []
    return stdcxx_flags(ctx)  # Defaults to 'libstdcxx'

# buildifier: disable=function-docstring
def stdcxx_flags(ctx):
    install_root = ctx.attr.install_root
    link_flags = ["-lstdc++", "-lm"]
    if ctx.attr.install_root and ctx.attr.install_root != "/usr":
        link_flags.append(
            "-Wl,-rpath," + install_root + "/lib64",
        )
    return [
        flag_set(
            actions = ALL_NON_STATIC_LINK_ACTIONS,
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
      flagset
    """
    if "libcxx" in ctx.features and ctx.attr.compiler != "clang":
        fail("ERROR: libcxx in only supported with the clang compiler")

    install_root = ctx.attr.install_root
    architecture = ctx.attr.architecture

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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
            flag_groups = ([flag_group(flags = ["-flto=thin"])]),
        ),
    ]
    if ctx.attr.compiler == "gcc":
        return _LTO_GCC_FLAGS
    if ctx.attr.compiler == "clang":
        return _LTO_CLANG_FLAGS
    fail("ERROR: invalid compiler")

# buildifier: disable=function-docstring
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

# buildifier: disable=function-docstring
def gold_linker_flags(ctx):
    return [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = ([flag_group(flags = ["-fuse-ld=gold"])]),
        ),
    ]

# buildifier: disable=function-docstring
def lld_linker_flags(ctx):
    return [
        flag_set(
            actions = LINK_ACTIONS,
            flag_groups = ([flag_group(flags = ["-fuse-ld=lld"])]),
        ),
    ]

# buildifier: disable=function-docstring
def toolchain_linker_flags(ctx):
    has_lld_linker = "lld_linker" in ctx.features
    has_gold_linker = "gold_linker" in ctx.features
    if has_lld_linker or has_gold_linker:
        return []
    return gold_linker_flags(ctx) if ctx.attr.compiler == "gcc" else lld_linker_flags(ctx)

# buildifier: disable=function-docstring
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
    fail("ERROR: invalid compiler")

# buildifier: disable=function-docstring
def runtime_library_search_flags(ctx):
    return [
        flag_set(
            actions = ALL_NON_STATIC_LINK_ACTIONS,
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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
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

# buildifier: disable=function-docstring
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
            actions = ALL_NON_STATIC_LINK_ACTIONS + [
                "objc-executable",
                "objc++-executable",
            ],
            flag_groups = [
                flag_group(flags = ["-fprofile-instr-generate"]),
            ],
        ),
    ]

# buildifier: disable=function-docstring
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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
            flag_groups = [flag_group(flags = ["--coverage"])],
        ),
    ]

# buildifier: disable=function-docstring
def coverage_flags(ctx):
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
            actions = ALL_NON_STATIC_LINK_ACTIONS,
            flag_groups = ([
                flag_group(flags = ctx.attr.coverage_link_flags),
            ] if ctx.attr.coverage_link_flags else []),
        ),
    ]

# buildifier: disable=function-docstring
def strip_debug_symbols_flags(ctx):
    return [
        flag_set(
            actions = ALL_NON_STATIC_LINK_ACTIONS,
            flag_groups = [
                flag_group(
                    flags = ["-Wl,-S"],
                    expand_if_available = "strip_debug_symbols",
                ),
            ],
        ),
    ]

# buildifier: disable=function-docstring
def make_c_cxx_standards_features(ctx):
    c_standards = [
        "c89",
        "gnu89",
        "c90",
        "gnu90",
        "c99",
        "gnu99",
        "c11",
        "gnu11",
        "c17",
        "gnu17",
        "c18",
        "gnu18",
        "c2x",
        "gnu2x",
    ]

    cxx_standards = [
        "c++98",
        "gnu++98",
        "c++03",
        "gnu++03",
        "c++11",
        "gnu++11",
        "c++14",
        "gnu++14",
        "c++17",
        "gnu++17",
        "c++2a",
        "gnu++2a",
        "c++20",
        "gnu++20",
        "c++2b",
        "gnu++2b",
        "c++23",
        "gnu++23",
        "c++2c",
        "gnu++2c",
        "c++26",
        "gnu++26",
    ]

    c_standards = [
        feature(
            name = std,
            flag_sets = [make_flagset(ALL_C_COMPILE_ACTIONS, ["-std=" + std])],
        )
        for std in c_standards
    ]
    cxx_standards = [
        feature(
            name = std,
            flag_sets = [make_flagset(ALL_CPP_COMPILE_ACTIONS, ["-std=" + std])],
        )
        for std in cxx_standards
    ]
    return c_standards + cxx_standards

def make_base_features(ctx):
    """Makes the features for the compiler.

    Args:
      ctx: The compiler rule context.

    Returns:
      The compiler features.
    """

    # Sanity checks
    if ctx.attr.compiler != "gcc" and ctx.attr.compiler != "clang":
        fail("ERROR: only supports 'gcc' and 'clang' compilers")
    has_libcxx = "libcxx" in ctx.features
    has_stdcxx = "stdcxx" in ctx.features
    if has_libcxx and has_stdcxx:
        fail("ERROR: Cannot specify both libcxx and stdcxx!")
    has_lld_linker = "lld_linker" in ctx.features
    has_gold_linker = "gold_linker" in ctx.features
    if has_lld_linker and has_gold_linker:
        fail("ERROR: Cannot specify both the 'lld' and 'gold' linkers at once!")

    return [
        feature(name = "defaults", enabled = True, flag_sets = default_flagsets(ctx)),
    ] + make_c_cxx_standards_features(ctx) + [

        # Optimization levels
        feature(name = "dbg"),
        feature(name = "fastbuild"),
        feature(name = "opt"),
        feature(name = "benchmark", implies = ["fastbuild"]),

        # Preprocessor Options
        feature(
            name = "no_canonical_system_headers",
            enabled = True,
            flag_sets = no_canonical_system_headers_flags(ctx),
        ),

        # Standard Library
        feature(name = "default_stdlib", enabled = True, flag_sets = default_stdlib_flags(ctx)),
        feature(name = "stdcxx", enabled = False, flag_sets = stdcxx_flags(ctx)),
        feature(name = "libcxx", enabled = False, flag_sets = libcxx_flags(ctx)),

        # Pic
        feature(name = "pic", enabled = False, flag_sets = pic_flags(ctx)),
        feature(name = "supports_pic", enabled = True),

        # Warnings
        feature(name = "warnings", enabled = True, flag_sets = warning_flags(ctx)),
        feature(name = "warn_error", enabled = False, flag_sets = warning_error_flags(ctx)),

        # Sanitizers
        feature(name = "asan", enabled = False, flag_sets = asan_flags(ctx)),
        feature(name = "usan", enabled = False, flag_sets = usan_flags(ctx)),
        feature(name = "ubsan", enabled = False, flag_sets = usan_flags(ctx)),
        feature(name = "tsan", enabled = False, flag_sets = tsan_flags(ctx), implies = ["pic"]),

        # Linkers
        feature(name = "gold_linker", enabled = False, flag_sets = gold_linker_flags(ctx)),
        feature(name = "lld_linker", enabled = False, flag_sets = lld_linker_flags(ctx)),
        feature(name = "toolchain_linker", enabled = True, flag_sets = toolchain_linker_flags(ctx)),

        # Extra linker flags
        feature(name = "shared_flag", flag_sets = shared_flags(ctx)),
        feature(name = "lto", enabled = False, flag_sets = lto_flags(ctx), implies = ["toolchain_linker"]),
        feature(name = "supports_start_end_lib", enabled = True),
        feature(
            # Add rpaths to binary
            name = "runtime_library_search_directories_feature",
            enabled = True,
            flag_sets = runtime_library_search_flags(ctx),
        ),

        # Misc. Features
        feature(name = "coverage", flag_sets = coverage_flags(ctx), provides = ["profile"]),
        feature(name = "strip_debug_symbols", flag_sets = strip_debug_symbols_flags(ctx)),
    ]

def calculate_toolchain_paths(ctx):
    """
    Calculates the toolchain paths as specified by the compiler context

    Args:
      ctx: The compiler context

    Returns:
      A list of 'tool_path' for a 'gcc' or 'clang' compiler
    """

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
    "prefix": attr.string(),  # prefix prepended before tool name
    "suffix": attr.string(),  # suffix appended to tools, like "-9" for "gcc-9"
    "architecture": attr.string(mandatory = True),  # 'x86_64-linux-gnu' etc
    "toolchain_identifier": attr.string(mandatory = True),
    "host_system_name": attr.string(mandatory = True),
    "target_system_name": attr.string(mandatory = True),
    "target_libc": attr.string(mandatory = True),
    "abi_version": attr.string(mandatory = True),
    "abi_libc_version": attr.string(mandatory = True),
    "cxx_builtin_include_directories": attr.string_list(mandatory = True),
    "tool_paths": attr.string_dict(),
    "supports_start_end_lib": attr.bool(),
    "llvm_toolchain_root": attr.string_list(),

    # Misc clags
    "warning_flags": attr.string_list(),  # For the feature: --features=warnings
    "extra_include_directories": attr.string_list(),
    "builtin_sysroot": attr.string(),

    # Compilation flags
    "base_compile_flags": attr.string_list(),
    "dbg_compile_flags": attr.string_list(),
    "opt_compile_flags": attr.string_list(),
    "coverage_compile_flags": attr.string_list(),
    "benchmark_compile_flags": attr.string_list(),
    "c_flags": attr.string_list(),
    "cxx_flags": attr.string_list(),

    # Linker flags
    "base_link_flags": attr.string_list(),
    "dbg_link_flags": attr.string_list(),
    "opt_link_flags": attr.string_list(),
    "coverage_link_flags": attr.string_list(),
    "benchmark_link_flags": attr.string_list(),
    "link_libs": attr.string_list(),
}

ToolPathsAndFeaturesInfo = provider(
    "z",
    fields = {
        "tool_paths": "info",
        "features": "info",
    },
)

# buildifier: disable=function-docstring
def _impl(ctx):
    tool_paths = calculate_toolchain_paths(ctx)
    extra_inc_dirs = ctx.attr.extra_include_directories if ctx.attr.extra_include_directories else []
    build_inc_dirs = ctx.attr.cxx_builtin_include_directories + extra_inc_dirs
    features = make_base_features(ctx)
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
            features = features,
            cxx_builtin_include_directories = build_inc_dirs,
        ),
        ToolPathsAndFeaturesInfo(
            tool_paths = tool_paths,
            features = features,
        ),
    ]

unix_toolchain_config = rule(
    implementation = _impl,
    attrs = COMMON_ATTRIBUTES,
    provides = [DefaultInfo, CcToolchainConfigInfo, ToolPathsAndFeaturesInfo],
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
        "include/" + architecture + "/c++/v1",
    ] + with_version(version) + with_version(major_version)

    return [clang_installation_path + "/" + x for x in paths]

def compiler_default_directories(compiler, install_root, architecture, version):
    """
    Calculate the default (builtin) c++ system header directories

    Args:
      compiler: Should be 'gcc' or 'clang'.
      install_root: The install root prefix for the toolchain; tool is at, eg, {prefix}/bin/gcc-9.
      architecture: The "machine", used to locate include directories.
      version: The tool version string used to locate c++ headers.

    Returns:
      flagset suitable for a compiler 'feature'.
    """
    base_directories = [
        "/usr/include/" + architecture,
        "/usr/include",
    ]
    if compiler == "gcc":
        return base_directories + calculate_gcc_include_directories(install_root, architecture, version)
    elif compiler == "clang":
        return base_directories + calculate_clang_include_directories(install_root, architecture, version)
    fail("ERROR: invalid compiler")

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
      install_root: Prefix to find installation root
      prefix: <install_root>/bin/<prefix>gcc<suffix>
      suffix: Suffix added to certain toolchain programs
      architecture: Something like 'x86_64-linux-gnu'
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
        fail("ERROR: invalid compiler")

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

def make_toolchain_from_install_root(
        name,
        install_root,
        additional_args,
        sys_machine,
        host_cxx_builtin_dirs,
        is_host_compiler):
    """Logic to deduce toolchain parameters from install_root only.

    Args:
      name: The name for the rule
      install_root: Toolchain directory
      additional_args: A list of list of strings that gets spliced into the toolchain configuration.
      sys_machine: The output of `gcc -machinedump`
      host_cxx_builtin_dirs: Sandbox breaking include directories necessary for host compiler (only).
      is_host_compiler: True if setting up the host compiler.
    """
    label = name
    config_label = label + "_config"
    version = None

    if is_host_compiler:
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
            fail("ERROR: could not deduce clang/gcc from install_root: {}".format(install_root))
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
    executable = True,  # You can do 'bazel run' on this rule
    attrs = {
        "src": attr.string(),
    },
)
