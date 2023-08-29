

_COVERAGE_COMPILE_FLAGS = ["-DNDEBUG"]

COMPILE_LINK_FLAGS = {
    # For the feature: --features=warnings
    "warning_flags": [
        "-Wall",
        "-Wextra",
    ],
    "base_compile_flags": [],
    "dbg_compile_flags": [
        "-g",
        "-O0",
        "-fno-omit-frame-pointer",
    ],
    "opt_compile_flags": [
        "-DNDEBUG",
        "-O3",
        "-ffunction-sections",  # necessary for deadcode elimination
        "-fdata-sections",  # ibid
        "-fstack-protector",  # basic buffer-overflow protection
    ],
    "benchmark_compile_flags": [
        "-DNDEBUG",
        "-O3",
        "-fno-omit-frame-pointer",
    ],
    "base_link_flags": [],
    "dbg_link_flags": [
        "-g",
        "-Wl,-no-as-needed",  # turn off "weak-linking" optimization
        "-Wl,-z,relro,-z,now",
    ],
    "opt_link_flags": [
        "-Wl,--gc-sections",  # linker garbage collects deadcode
        "-Wl,-z,relro",  # shared-library jump table is read-only
        "-Wl,-z,now",  # dynamic linker eagerly binds symbols
    ],
    "benchmark_link_flags": [
        "-Wl,-z,now",
    ],
    "coverage_compile_flags": _COVERAGE_COMPILE_FLAGS,
}


