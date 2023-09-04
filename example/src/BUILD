load("@rules_cc//cc:defs.bzl", "cc_binary", "cc_library")

package(features = ["-tsan"],
        default_visibility = ["//visibility:public"])

cc_binary(
    name = "main",
    srcs = ["main.cc"],
    deps = [
        ":some_lib_lib",
        "@fmtlib//:fmt",
    ],
    copts = ["-pedantic"],
)

cc_library(
    name = "some_lib_lib",
    srcs = ["some_lib.cc"],
    hdrs = ["some_lib.h"],
    deps = [
        "@fmtlib//:fmt",
    ],
)
