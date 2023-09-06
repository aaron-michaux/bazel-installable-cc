"""
TBD
"""

# -------------------------------------------------------------- starlark helpers

def make_info_warn_script(repo_ctx, filename, level, colour_id):
    if not repo_ctx.path(filename).exists:
        colour = "\\e[{}m".format(colour_id) if colour_id else ""
        reset_colour = "\\e[0m" if colour_id else ""        
        repo_ctx.file(
            filename,
            content = """#!/bin/bash
printf '{}%s:{} %s\n' "{}" "$*"
""".format(colour, reset_colour, level),
            executable = True,
        )    

def info(repo_ctx, message):
    """Outputs an info message."""
    make_info_warn_script(repo_ctx, "info.sh", "INFO", "32")
    repo_ctx.execute(["./info.sh", message], quiet = False)

def warn(repo_ctx, message):
    """Outputs a warning message."""
    make_info_warn_script(repo_ctx, "warn.sh", "WARN", "33")
    repo_ctx.execute(["./warn.sh", message], quiet = False)

def there_will_be_only_once(repo_ctx):
    """Bazel seems to execute this rule multiple times unless you slow it down"""
    repo_ctx.execute(["sleep", "0.1"], quiet = False)

# ----------------------------------------------------------------- bash helpers

def bash_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"

# ---------------------------------------------------------- determine toolchain

def get_host_machine(repo_ctx):
    return repo_ctx.execute(["gcc", "-dumpmachine"]).stdout.strip()

def is_inc_dir(repo_ctx, line):
    return len(line) > 0 and line[0] == "/" and repo_ctx.path(line).exists

def get_compiler_inc_dirs(repo_ctx, compiler):
    repo_ctx.file(
        "sys_inc_dirs.sh",
        content = "echo '' | {} -E -v -xc++ -".format(compiler),
        executable = True,
    )
    host_inc_dirs_flat = repo_ctx.execute(["./sys_inc_dirs.sh"])
    all_output = host_inc_dirs_flat.stdout + host_inc_dirs_flat.stderr
    lines = [x.strip() for x in (all_output).split("\n")]
    inc_dirs = [x for x in lines if is_inc_dir(repo_ctx, x)]
    return inc_dirs

def get_host_cxx_inc_dirs(repo_ctx):
    return get_compiler_inc_dirs(repo_ctx, "cc")
    
def get_os_value(repo_ctx):
    # Is there an override value?
    override_value = repo_ctx.os.environ.get("override-operating-system", None)
    if override_value:
        return override_value
    os_name = repo_ctx.os.name
    if os_name.startswith("mac os"):
        return "darwin"
    if os_name.find("linux") != -1:
        return "linux"
    fail("Operating system not supported: {}", os_name)

def get_cpu_value(repo_ctx):
    """Computer the CPU value used to initialize the toolchain"""

    # Is there an override value?
    override_value = repo_ctx.os.environ.get("override-host_cpu")
    if override_value:
        return override_value
    arch = repo_ctx.os.arch
    if arch in ["amd64", "x86_64", "x64"]:
        return "x86_64"
    if arch in ["arm", "armv7l"]:
        return "arm"
    if arch in ["aarch64"]:
        return "aarch64"
    fail("Architecture not supported: {}", arch)

def get_default_vendor(repo_ctx):
    if get_os_value(repo_ctx) != "linux":
        return ""
    repo_ctx.file(
        "determine_linux_vendor.sh",
        content = """#!/bin/bash
if [ -x "/usr/bin/lsb_release" ] ; then    
    /usr/bin/lsb_release -a 2>/dev/null | grep Codename | awk '{ print $2 }' | tr '[:upper:]' '[:lower:]'
elif [ -f /etc/os-release ] && cat /etc/os-release | grep -qi Oracle  ; then
    ol$(cat /etc/os-release | grep -E ^VERSION= | awk -F= '{ print $2 }' | sed 's,",,g')
fi
""",
        executable = True,
    )
    return repo_ctx.execute(["./determine_linux_vendor.sh"]).stdout.strip()

def parse_manifest_line(line):
    # Should be HASH  <compiler--cpu--vendor--os>
    # Output: (filename, compiler, cpu, vendor, os, HASH)
    if line == "" or line.startswith("#"):
        return None  # Empty/comment line
    parts = [x.strip() for x in line.split(" ") if x != ""]
    if len(parts) != 2:
        return None

    hash = parts[0]
    filename = parts[1]

    # Decode the file parts
    parts = [x for x in filename.split("--")]
    if len(parts) != 3 and len(parts) != 4:
        return None

    toolname = parts[0]
    cpu = parts[1]
    vendor = "" if len(parts) == 3 else parts[2]
    os_plus_ext = parts[-1]

    # Remove the extension from `os_plus_ext`
    parts = os_plus_ext.split(".")
    os = parts[0]

    return (filename, toolname, cpu, vendor, os, hash)

def parse_manifest(text):
    items = [parse_manifest_line(x) for x in text.split("\n")]
    return [x for x in items if x]

def determine_toolchain_linux(repo_ctx):
    toolchain = repo_ctx.os.environ.get("compiler")
    os = get_os_value(repo_ctx)
    cpu = get_cpu_value(repo_ctx)
    vendor = repo_ctx.os.environ.get("compiler-vendor")  # None is fine
    default_vendor = get_default_vendor(repo_ctx)

    if not toolchain or toolchain == "":
        fail("Must specify a toolchain!")

    # Parse the manifest
    manifest = parse_manifest(repo_ctx.attr.manifest)

    # Filter the manifest
    filtered = [
        x
        for x in manifest
        if x[1].startswith(toolchain) and
           x[2] == cpu and
           (not vendor or x[3] == "" or x[3] == vendor) and
           x[4] == os
    ]

    if len(filtered) > 1 and not vendor and default_vendor and default_vendor != "":
        # A vendor wasn't specified, so try to narrow results based on OS default
        filtered = [x for x in filtered if x[3] == default_vendor]

    if len(filtered) == 0:
        fail("Failed to determined toolchain, toolchain: {}, cpu: {}, vendor: {}, os: {}, default_vendor: {}".format(toolchain, cpu, vendor, os, default_vendor))
    if len(filtered) > 1:
        fail("Multiple toolchains selected, toolchain: {}, cpu: {}, vendor: {}, os: {}, default_vendor: {}, selected: [\"{}\"]".format(toolchain, cpu, vendor, os, default_vendor, "\", \"".join(
            [key for key, x in filtered],
        )))

    archivename, toolname, _, _, _, hash = filtered[0]
    return archivename, toolname, hash

def determine_toolchain_darwin(repo_ctx):
    toolchain = repo_ctx.os.environ.get("compiler")
    os = get_os_value(repo_ctx)
    cpu = get_cpu_value(repo_ctx)

    # Always get toolchains via brew, gcc/clang, major versions only
    toolchain_parts = toolchain.split("-")
    if len(toolchain_parts) <= 1:
        fail("Could not determine major version in toolchain: {}".format(toolchain))
    product = toolchain_parts[0]
    major_version = toolchain_parts[1].split(".")[0]
    if product not in ["gcc", "llvm"]:
        fail("Only supports gcc/llvm on macox, toolchain: {}".format(toolchain))    

    # About the tool
    toolname = ("gcc-" + major_version) if (product == "gcc") else "clang"
    brew_package = "{}@{}".format(product, major_version)

    # This *should* be the path to the tool
    install_dir = "/opt/homebrew/opt/{}".format(brew_package)
    toolpath = "{}/bin/{}".format(install_dir, toolname)
    if repo_ctx.path(toolpath).exists:
        return install_dir, toolpath, brew_package # We're good
        
    # This is the brew package
    repo_ctx.file(
        "brew_check_and_install.sh",
        executable = True,
        content = """#!/bin/bash
brew install $1
""")        
    
    info(repo_ctx, "Checking brew installation for package: {}".format(brew_package))
    repo_ctx.execute(["./brew_check_and_install.sh", brew_package], quiet = False)

    if not repo_ctx.path(toolpath).exists:
        fail("Still could not find tool after installation, package: {}, path: {}".format(brew_package, toolpath))

    return install_dir, toolpath, brew_package

# --------------------------------------------------------- download and extract

def strip_tar_extension(filename):
    parts = filename.split(".")
    if len(parts) > 1:
        parts.pop()
    if len(parts) > 1 and parts[-1] == "tar":
        parts.pop()
    return ".".join(parts)

def get_install_directory(destination_dir, archive_name):
    return "{}/{}".format(destination_dir, strip_tar_extension(archive_name))

def get_install_lock_filename(destination_dir, archive_name):
    return "{}/.install-lock".format(get_install_directory(destination_dir, archive_name))

def is_extracted(repo_ctx, archive_name, expected_hash, destination_dir):
    install_lock_filename = get_install_lock_filename(destination_dir, archive_name)
    if repo_ctx.path(install_lock_filename).exists:
        installed_hash = repo_ctx.read(install_lock_filename).strip()
        if installed_hash != expected_hash:
            fail("Unexpected hash in installation, lock-file: {}, expected-hash: {}, installed-hash: {}"
                .format(install_lock_filename, expected_hash, installed_hash))
        return True
    return False

def file_sha256(repo_ctx, filename):
    if not repo_ctx.path(filename).exists:
        return None
    ret = repo_ctx.execute(["sha256sum", filename])
    if ret.return_code != 0:
        fail(
            "Failed to extract hash, cmd: sha256sum {}, exitcode: {}, stderr: {}",
            bash_quote(filename),
            ret.return_code,
            ret.stderr,
        )
    out_parts = ret.stdout.split(" ")
    return out_parts[0]

def download_one(repo_ctx, url, archive_name, expected_hash, cache_file):
    full_url = "{}/{}".format(url, archive_name)

    # Does the cache file exist?
    file_hash = file_sha256(repo_ctx, cache_file)
    if file_hash == expected_hash:
        # Does it have the correct hash?
        info(repo_ctx, "download file is already cached and passes hash-check, skipping download")
        return True

    # Otherwise attempt to downdload
    log_file = "{}.wget.log".format(cache_file)
    cmd = ["wget", "-t", "3", "--show-progress", "-O", cache_file, "-o", log_file]
    if repo_ctx.attr.no_check_certificate:
        cmd.append("--no-check-certificate")
    cmd.append(full_url)
    ret = repo_ctx.execute(cmd)
    if ret.return_code != 0:
        info(repo_ctx, "download failed, url: {}, exitcode: {}"
            .format(full_url, ret.return_code))
        return False  # We can ignore this error, download will try again

    if not repo_ctx.path(cache_file).exists:
        fail("wget download succeeded; however, cache-file does not exist! file: {}".format(cache_file))

    # Check the hash
    file_hash = file_sha256(repo_ctx, cache_file)
    if file_hash != expected_hash:
        fail("Hash mismatch, file: {}, hash: {}, expected-hash: {}"
            .format(cache_file, file_hash, expected_hash))
    return True

def download_and_extract_one(
        repo_ctx,
        url,
        archive_name,
        expected_hash,
        destination_dir,
        download_cache_dir):
    if is_extracted(repo_ctx, archive_name, expected_hash, destination_dir):
        return True

    info(repo_ctx, "downloading url: {}".format("{}/{}".format(url, archive_name)))
    cache_file = "{}/{}".format(download_cache_dir, archive_name)
    if not download_one(repo_ctx, url, archive_name, expected_hash, cache_file):
        return False  # we'll try another url

    # If the installation directory exists, assume a partial download and delete the directory
    install_dir = "{}/{}".format(destination_dir, strip_tar_extension(archive_name))
    if repo_ctx.path(install_dir).exists:
        info(repo_ctx, "install directory exists; untarring over it; directory: {}".format(install_dir))
    else:
        info(repo_ctx, "untarring to directory: {}".format(destination_dir))

    # At this stage we have a downloaded cache file with a matching hash, extract it
    extract_cmd = ["tar", "-C", destination_dir, "-xf", cache_file]
    ret = repo_ctx.execute(extract_cmd)
    if ret.return_code != 0:
        warn(repo_ctx, "failed to extract tarball, file: {}, exitcode: {}, stderr: {}".format(cache_file, ret.return_code, ret.stderr))
        return False

    if not repo_ctx.path(install_dir).exists:
        warn(repo_ctx, "tarball extract but expected install-directory did not appear, file: {}, install-dir: {}".format(cache_file, install_dir))
        return False

    # Place the install lockfile
    install_lock_filename = get_install_lock_filename(destination_dir, archive_name)
    write_hash_sh = "write_hash_" + expected_hash + ".sh"
    repo_ctx.file(
        write_hash_sh,
        content = """#!/bin/bash
echo {} > {}
""".format(bash_quote(expected_hash), bash_quote(install_lock_filename)),
        executable = True,
    )
    ret = repo_ctx.execute(["./" + write_hash_sh])
    if ret.return_code != 0:
        warn(repo_ctx, "failed to write hash to installation directory, exitcode: {}, stderr: {}", ret.return_code, ret.stderr)
        return False
    else:
        info(repo_ctx, "installation complete: {}".format(install_dir))
    return True

def download_and_extract(
        repo_ctx,
        urls,
        archive_name,
        expected_hash,
        destination_dir,
        download_cache_dir):
    # If we don't have an installation, then try each URL in turn to get one
    if not is_extracted(repo_ctx, archive_name, expected_hash, destination_dir):
        for url in urls:
            if download_and_extract_one(
                repo_ctx,
                url,
                archive_name,
                expected_hash,
                destination_dir,
                download_cache_dir,
            ):
                break

    # Check again to ensure we have an installation
    if not is_extracted(repo_ctx, archive_name, expected_hash, destination_dir):
        if len(urls) == 0:
            fail("Failed to download toolchain, no urls specified! archive: {}".format(archive_name))
        fail("Failed to download toolchain, all urls tried, archive: {}, expected-hash: {}".format(archive_name, expected_hash))
    return True

# ----------------------------------------------------- initialization repo-rule

def get_bazel_cache_dir(repo_ctx):
    os = get_os_value(repo_ctx)
    if os == "linux":
        home_dir = repo_ctx.os.environ.get("HOME")
        if not home_dir:
            fail("failed to determine HOME environment variable")
        return home_dir.strip() + "/.cache/bazel"
    elif os == "darwin":
        return "/private/var/tmp"
    fail("unrecognized os: '{}'".format(os))

def _initialization_impl(repo_ctx):
    # Copy in :toolchain_common.bzl
    repo_ctx.file("clang_format.bzl", content = repo_ctx.read(Label("//internal:clang_format.bzl")), executable = False)
    repo_ctx.file("clang_tidy.bzl", content = repo_ctx.read(Label("//internal:clang_tidy.bzl")), executable = False)
    repo_ctx.file("common.bzl", content = repo_ctx.read(Label("//internal:common.bzl")), executable = False)
    repo_ctx.file("compile_commands.bzl", content = repo_ctx.read(Label("//internal:compile_commands.bzl")), executable = False)
    repo_ctx.file("defs.bzl", content = repo_ctx.read(Label("//internal:defs.bzl")), executable = False)
    repo_ctx.file("toolchain_common.bzl", content = repo_ctx.read(Label("//internal:toolchain_common.bzl")), executable = False)

    compiler_env = repo_ctx.os.environ.get("compiler", "host")
    os = get_os_value(repo_ctx)
    if os not in ["linux", "darwin"]:
        fail("Only supports linux/darwin, os: {}".format(os))
    is_linux = (os == "linux")
    is_darwin = (os == "darwin")

    # Basic environment
    bazel_cache_dir = get_bazel_cache_dir(repo_ctx)
    toolchain_install_prefix = bazel_cache_dir + "/toolchains"
    download_cache_dir = bazel_cache_dir + "/toolchains/downloads"
    host_cxx_inc_dirs = get_host_cxx_inc_dirs(repo_ctx)
    host_machine = get_host_machine(repo_ctx)

    # Determine the toolchain
    use_host_toolchain = (compiler_env == "host")
    toolchain_directory = ""
    if use_host_toolchain:
        # These values are necessary to configure the host toolchain
        toolchain_directory = "/usr"
        info(repo_ctx, "selecting host compiler")
    elif is_linux:
        archive_name, toolname, hash = determine_toolchain_linux(repo_ctx)

        # Download and install the toolchain
        download_and_extract(
            repo_ctx,
            urls = repo_ctx.attr.download_urls,
            archive_name = archive_name,
            expected_hash = hash,
            destination_dir = toolchain_install_prefix,
            download_cache_dir = download_cache_dir,
        )

        toolchain_directory = get_install_directory(toolchain_install_prefix, archive_name)
        info(repo_ctx, "selecting compiler: {}".format(repo_ctx.path(toolchain_directory).basename))
    elif is_darwin:
        # This determines the toolname, and installs it (using brew) is necessary
        toolchain_directory, tool_path, toolchain_version = determine_toolchain_darwin(repo_ctx)

        # Override the installation directories for this compiler
        host_cxx_inc_dirs = get_compiler_inc_dirs(repo_ctx, tool_path)
        
        info(repo_ctx, "selecting compiler: {}".format(toolchain_version))

    # Set up the BUILD template
    flags = repo_ctx.attr.toolchain_flags if repo_ctx.attr.toolchain_flags else []
    template_substitutions = {
        "%{toolchain_directory}": repr(toolchain_directory),
        "%{sysmachine}": repr(host_machine),
        "%{host_cxx_builtin_dirs}": repr(host_cxx_inc_dirs),
        "%{use_host_compiler}": repr(use_host_toolchain),
        "%{toolchain_flags}": repr(flags),
        "%{os}": repr(os),
    }

    # Create the BUILD file
    repo_ctx.template("BUILD", Label("//internal:BUILD.tpl"), template_substitutions, executable = False)

initialization = repository_rule(
    implementation = _initialization_impl,
    local = True,
    attrs = {
        "download_urls": attr.string_list(mandatory = True),
        "manifest": attr.string(mandatory = True),
        "toolchain_flags": attr.string_list_dict(mandatory = False),
        "no_check_certificate": attr.bool(mandatory = False),
    },
)

# --------------------------------------------------------- initialize-toolchain

def initialize_toolchain(name, urls, manifest, toolchain_flags = {}, no_check_certificate = False):
    initialization(
        name = name,
        download_urls = urls,
        manifest = manifest,
        toolchain_flags = toolchain_flags,
        no_check_certificate = no_check_certificate,
    )
    native.register_toolchains("@" + name + "//:cc")
