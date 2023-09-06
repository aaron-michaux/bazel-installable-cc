"""
Compiler flags that are active for *all* builds, including builds of 3rd party dependencies.

TEST your compiler flags using:

   bazel build --subcommands //path/to:target

"""

# A dictionary of key-value pairs that are passed to the toolchain configuration
TOOLCHAIN_FLAGS = {
    # For the feature: --features=warnings
    "warning_flags": [
        # Include ["-Wall"]
    ],
    "base_compile_flags": [
        # Extra flags passed to all compile actions
    ],
    "c_flags": [
        # Flags passed to CXX compilation only
    ],
    "cxx_flags": [
        # Flags passed to CXX compilation only
    ],
    "dbg_compile_flags": [
        # Extra flags when building `-c dbg`
        # Includes: ["-O0", "-g"]
    ],
    "opt_compile_flags": [
        "-fstack-protector",  # basic buffer-overflow protection
        # Includes: ["-O3", "-DNDEBUG", "-ffunction-sections", "-fdata-sections"]
    ],
    "coverage_compile_flags": [
        # Link flags passed when --features coverage
        "-DNDEBUG",
    ],
    "benchmark_compile_flags": [
        # Includes: ["-O3", "-DNDEBUG", "-g", "-fno-omit-frame-pointer"]
    ],
    "base_link_flags": [
        # Passed to all link actions
    ],
    "dbg_link_flags": [
        "-Wl,-z,relro,-z,now",
        # Includes: ["-g", "-Wl,-no-as-needed"]
    ],
    "opt_link_flags": [
        "-Wl,-z,relro",  # shared-library jump table is read-only
        "-Wl,-z,now",  # dynamic linker eagerly binds symbols
        # Includes: ["-Wl,--gc-sections"]
    ],
    "coverage_link_flags": [
        # Link flags passed when --features coverage
    ],
    "benchmark_link_flags": [
        "-Wl,-z,now",  # dynamic linker eagerly binds symbols
    ],
}
