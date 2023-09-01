workspace(name = "installable_toolchain")

# -- This workspace file is setup to test the installable-cc toolchain

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

# -- Dependencies use by the build system

http_archive(
    name = "bazel_skylib",
    sha256 = "66ffd9315665bfaafc96b52278f57c7e2dd09f5ede279ea6d39b2be471e7e3aa",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-1.4.2.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-1.4.2.tar.gz",
    ],
)

git_repository(
    name = "rules_cc",
    commit = "7771fb57dd4d044aff08c2125d3ba5c8aaeef424",
    remote = "https://github.com/bazelbuild/rules_cc.git"
)

git_repository(
    name = "com_github_bazelbuild_buildtools",
    remote = "https://github.com/bazelbuild/buildtools.git",
    commit = "b163fcf72b7def638f364ed129c9b28032c1d39b",
)

git_repository(
    name = "bazel_clang_tidy",
    commit = "133d89a6069ce253a92d32a93fdb7db9ef100e9d",
    remote = "https://github.com/erenon/bazel_clang_tidy.git",
)

git_repository(
    name = "hedron_compile_commands",
    commit = "e16062717d9b098c3c2ac95717d2b3e661c50608",
    remote = "https://github.com/hedronvision/bazel-compile-commands-extractor.git",
)

load("//example/config:toolchain_config.bzl", "URLS", "MANIFEST")
load("//example/config:toolchain_flags.bzl", "TOOLCHAIN_FLAGS")
load("//:initialization.bzl", "initialize_toolchain")
initialize_toolchain(
    urls = URLS,                       # Where toolchains are downloaded from
    manifest = MANIFEST,               # Availabe toolchains
    toolchain_flags = TOOLCHAIN_FLAGS, # Flag customization
    no_check_certificate = True,       # For https, don't check certs
)

# -- Workspace Setup

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
bazel_skylib_workspace()

load("@hedron_compile_commands//:workspace_setup.bzl", "hedron_compile_commands_setup")
hedron_compile_commands_setup()

# -- Load Buid dependencies

http_archive(
    name = "fmtlib",        
    strip_prefix = "fmt-10.1.0",        
    sha256 = "deb0a3ad2f5126658f2eefac7bf56a042488292de3d7a313526d667f3240ca0a",        
    urls = ["https://github.com/fmtlib/fmt/archive/refs/tags/10.1.0.tar.gz"],
    build_file = "//example/config/external:fmtlib.BUILD",
)

