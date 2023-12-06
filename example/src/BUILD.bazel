load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

package(
    default_visibility = ["//visibility:public"],
    features = ["-tsan"],
)

cc_binary(
    name = "main",
    srcs = ["main.cc"],
    copts = ["-pedantic"],
    deps = [
        ":some_lib_lib",
        "@fmtlib//:fmt",
    ],
)

cc_library(
    name = "some_lib_lib",
    srcs = ["some_lib.cc"],
    hdrs = ["some_lib.h"],
    deps = [
        "@fmtlib//:fmt",
    ],
)
