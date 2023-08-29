workspace(name = "rfts")

# -- Load in dependencies required for WORKSPACE
load("@//bazel:dependencies.bzl", "load_workspace_dependencies", "load_build_dependencies")
load_workspace_dependencies()

# -- Workspace setup
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
bazel_skylib_workspace()

# -- Pick up the c/c++ toolchain
load("//bazel/toolchain:initialization.bzl", "toolchain_initialization")
toolchain_initialization()
register_toolchains("//bazel/toolchain:cpp")

load("@hedron_compile_commands//:workspace_setup.bzl", "hedron_compile_commands_setup")
hedron_compile_commands_setup()

# -- Load dependencies
load_build_dependencies()

