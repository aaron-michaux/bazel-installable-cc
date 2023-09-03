load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

def project_cc_binary(name, srcs, data = [], deps = []):
    return native.cc_binary(
        name = name,
        srcs = srcs,
        data = ["//example/config/suppressions:all"],
    )
