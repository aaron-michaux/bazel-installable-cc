
# -- compiler_installation_check

# echo "" | gcc -E -v - 2>&1 | sed '0,/search starts here/d' | sed '/End of search/,$d' | grep -v \#include | sed 's,^ *,,'
def is_inc_dir(repo_ctx, line):
    return len(line) > 0 and line[0] == '/' and repo_ctx.path(line).exists

def get_sys_cxx_inc_dirs(repo_ctx):
    repo_ctx.file(
        "sys_inc_dirs.sh",
        content = "echo '' | gcc -E -v -xc++ -",
        executable=True
    )

    sysgcc_inc_dirs_flat = repo_ctx.execute(["./sys_inc_dirs.sh"])
    all_output = sysgcc_inc_dirs_flat.stdout + sysgcc_inc_dirs_flat.stderr
    lines = [x.strip() for x in (all_output).split("\n")]

    inc_dirs = [x for x in lines if is_inc_dir(repo_ctx, x)]
    return inc_dirs

def get_sys_machine(repo_ctx):
    return repo_ctx.execute(["gcc", "-dumpmachine"]).stdout.strip()

def initialization_impl_(repo_ctx):
    repo_ctx.file("BUILD", executable=False)    
    sys_cxx_inc_dirs = get_sys_cxx_inc_dirs(repo_ctx)

    # Needs to be a skylark string (machine generated code)
    sys_cxx_inc_dirs_str = "[]"
    if len(sys_cxx_inc_dirs) > 0:
        sys_cxx_inc_dirs_str = "[\"{}\"]".format("\", \"".join(sys_cxx_inc_dirs))

    home_dir = repo_ctx.os.environ.get("HOME")
    if not home_dir:
        fail("failed to determine HOME environment variable")
    bazel_cache_dir = home_dir.strip() + "/.cache/bazel"    
    toolchain_root = bazel_cache_dir + "/toolchains"
    toolchain_download = bazel_cache_dir + "/toolchains/downloads"
    
    # Placeholder file to allow instantiation of repostitory
    repo_ctx.file(
        "config.bzl",
        content="""
TOOLCHAIN_ROOT  = "{}"
TOOLCHAIN_DOWNLOAD = "{}"
SYS_CXX_INC_DIRS = {}
SYS_MACHINE = "{}"
""".format(
    toolchain_root,
    toolchain_download,
    sys_cxx_inc_dirs_str,
    get_sys_machine(repo_ctx)
),
        executable=False
    )
    

initialization = repository_rule(
    implementation = initialization_impl_,
)

def toolchain_initialization():
    initialization(
        name = "toolchain_initialization",
    )
