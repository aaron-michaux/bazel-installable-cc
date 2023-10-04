"""
Module to bring together useful rules for convenient loading in other modules.
"""

load(":clang_tidy.bzl", "clang_tidy_internal")
load(":clang_format.bzl", "clang_format_internal")
load(":compile_commands.bzl", "compile_commands_internal")
load(":make_makefile.bzl", "make_makefile_internal")

clang_tidy = clang_tidy_internal

clang_format = clang_format_internal

compile_commands = compile_commands_internal

make_makefile = make_makefile_internal
