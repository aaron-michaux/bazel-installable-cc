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
    remote = "https://github.com/bazelbuild/rules_cc.git",
)

# Buildifier is compiled by GO
http_archive(
    name = "io_bazel_rules_go",
    sha256 = "6dc2da7ab4cf5d7bfc7c949776b1b7c733f05e56edc4bcd9022bb249d2e2a996",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.39.1/rules_go-v0.39.1.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.39.1/rules_go-v0.39.1.zip",
    ],
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "727f3e4edd96ea20c29e8c2ca9e8d2af724d8c7778e7923a854b2c80952bc405",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.30.0/bazel-gazelle-v0.30.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.30.0/bazel-gazelle-v0.30.0.tar.gz",
    ],
)

http_archive(
    name = "com_google_protobuf",
    sha256 = "3bd7828aa5af4b13b99c191e8b1e884ebfa9ad371b0ce264605d347f135d2568",
    strip_prefix = "protobuf-3.19.4",
    urls = [
        "https://github.com/protocolbuffers/protobuf/archive/v3.19.4.tar.gz",
    ],
)

http_archive(
    name = "com_github_bazelbuild_buildtools",
    sha256 = "ae34c344514e08c23e90da0e2d6cb700fcd28e80c02e23e4d5715dddcb42f7b3",
    strip_prefix = "buildtools-4.2.2",
    urls = [
        "https://github.com/bazelbuild/buildtools/archive/refs/tags/4.2.2.tar.gz",
    ],
)

load("//example/config:toolchain_config.bzl", "MANIFEST", "URLS")
load("//example/config:toolchain_flags.bzl", "TOOLCHAIN_FLAGS")
load("//:initialization.bzl", "initialize_toolchain")

initialize_toolchain(
    name = "initialize_toolchain",
    manifest = MANIFEST,  # Availabe toolchains
    no_check_certificate = True,  # For https, don't check certs
    toolchain_flags = TOOLCHAIN_FLAGS,  # Flag customization
    urls = URLS,  # Where toolchains are downloaded from
)

# -- Workspace Setup

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

# for Buildifier
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

go_rules_dependencies()

go_register_toolchains(version = "1.20.3")

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

gazelle_dependencies()

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

# -- Load Buid dependencies

http_archive(
    name = "fmtlib",
    build_file = "//example/config/external:fmtlib.BUILD",
    sha256 = "deb0a3ad2f5126658f2eefac7bf56a042488292de3d7a313526d667f3240ca0a",
    strip_prefix = "fmt-10.1.0",
    urls = ["https://github.com/fmtlib/fmt/archive/refs/tags/10.1.0.tar.gz"],
)
