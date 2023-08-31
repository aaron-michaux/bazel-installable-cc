workspace(name = "rfts")

# -- Load in dependencies required for WORKSPACE
load("@//bazel:dependencies.bzl", "load_workspace_dependencies", "load_build_dependencies")
load_workspace_dependencies()

# -- Workspace setup
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
bazel_skylib_workspace()

# -- Pick up the c/c++ toolchain
load("//bazel/toolchain:toolchain_config.bzl", "URLS", "MANIFEST")
load("//bazel/toolchain:toolchain_flags.bzl", "TOOLCHAIN_FLAGS")
load("//bazel/toolchain:initialization.bzl", "initialize_toolchain")
initialize_toolchain(
    urls = URLS,                       # Where toolchains are downloaded from
    manifest = MANIFEST,               # Availabe toolchains
    toolchain_flags = TOOLCHAIN_FLAGS, # Flag customization
    no_check_certificate = True,       # For https, don't check certs
)

load("@hedron_compile_commands//:workspace_setup.bzl", "hedron_compile_commands_setup")
hedron_compile_commands_setup()

# -- Load dependencies
load_build_dependencies()

