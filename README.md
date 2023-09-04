
# Installable and Configurable Bazel CC Toolchains

By default, bazel picks up the system CC compiler. It is possible to create fully hermetic builds by installing [https://github.com/grailbio/bazel-toolchain](LLVM) and [https://github.com/aspect-build/gcc-toolchain](GCC) compilers directly into the sandbox. I found this unsatisfactory for a few reasons:

 1. We need to use `--output_base` to preserve bazels "analysis cache" for our many build configurations. We also use both LLVM and GCC. Placing these toolchains inside the sandbox explodes the size of the sandbox by more than 5Gb times every configuration we use.
 2. We need to use our own compiled compilers: the available GCC/LLVM toolchains aren't always built with our old glibc in mind.
 3. There are [https://github.com/grailbio/bazel-toolchain](performance issues) with placing the entire toolchain in the sandbox.
 
Furthermore, as a matter of professional development, I wanted to do this project to learn bazel.

## Solution for Installable and Configurable Bazel CC Toolchains

 * We have two scripts to build, and package, GCC and LLVM toolchains. These builds are sufficient for most uses of GCC/LLVM.
 * The archive(s) is placed on some URL, or simply on the local filesystem.
 * Toolchains are identified and selected by an environment variable (e.g., `--repo_env=compiler=llvm-16.0.6`)
 * A [https://bazel.build/extending/repo](repository rule) picks up the environment variable, and downloads and install the toolchain _outside_ the sandbox, but still hermetically. (In `$HOME/.cache/bazel/toolchains`.)
 * The toolchain can be customized by passing a dictionary of flags.
 * The available compilers (and download URLs) are passed in as configuration parameters.
 
## Supports

 * Linux only: Tested on Debian10, Ubuntu22.04, Oracle Linux 8.8

## Notes:

The `standalone` spawn strategy is required for `buildifier_fix` and `format_fix` to work.

 * bazel build --config static_analysis :static_analysis
 * bazel build //:buildifier_check
 * bazel build //:format_check
 * bazel build --spawn_strategy=standalone //:buildifier_fix
 * bazel build --spawn_strategy=standalone //:format_fix
 * bazel build :refresh_compile_commands

## TODOs

 * A trivial testcase, with sanitizer run files work
 * Buildifier
 * clang-format checks through aspect
 * Front end script (bazel aspects?? build.sh??? makefile????)
   - Front end should run under valgrind/helgrind with suppressions
   - Front end should auto-support gdb for any target
   - Ensure output-dir works -- no dumping of the analysis cache
 * Cross-compiler (is sysroot enough?)
 * Works on macos (with brew)


