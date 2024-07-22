
# Installable and Configurable Bazel CC Toolchains

By default, bazel picks up the system CC compiler. It is possible to create fully hermetic builds by installing [LLVM](https://github.com/grailbio/bazel-toolchain) and [GCC](https://github.com/aspect-build/gcc-toolchain) compilers directly into the sandbox. I found this unsatisfactory for a few reasons:

 1. We need to use `--output_base` to preserve bazels "analysis cache" for our many build configurations. We also use both LLVM and GCC. Placing these toolchains inside the sandbox explodes the size of the sandbox by more than 5Gb times for every configuration we use.
 2. The available GCC/LLVM toolchains aren't always built with our old glibc in mind.
 3. There are [performance issues](https://github.com/grailbio/bazel-toolchain) with placing the entire toolchain in the sandbox.
 
Furthermore, I wanted to do this project to learn something about bazel.

## Solution for Installable and Configurable Bazel CC Toolchains

 * We have two scripts to build, and package, GCC and LLVM toolchains. These builds are sufficient for most uses of GCC/LLVM.
 * The archive(s) is placed on some URL.
 * Toolchains are identified and selected by an environment variable (e.g., `--repo_env=compiler=llvm-16.0.6`)
 * A [repository rule](https://bazel.build/extending/repo) picks up the environment variable, and downloads and install the toolchain _outside_ the sandbox, but still hermetically. (In `$HOME/.cache/bazel/toolchains`.)
 * The toolchain can be customized by passing a struct of flags.
 * The available compilers (and download URLs) are passed in as configuration parameters.
 
## Supports

 * Linux only: Tested on Debian10, Debian11, Ubuntu22.04, Ubuntu24.04, Oracle Linux 8.9 and 8.10

## Notes:

The `standalone` spawn strategy is required for `buildifier_fix` and `format_fix` to work.
See `makefile` for examples of how to piece everything together

## TODOs

 * Remove all unnecessary stuff from WORKSPACE
 * A trivial testcase, with sanitizer run files work
 * Front end script (bazel aspects?? build.sh??? makefile????)
   - Front end should run under valgrind/helgrind with suppressions
   - Front end should auto-support gdb for any target
 * Cross-compiler (is sysroot enough?)
 * Works on macos (with brew)

