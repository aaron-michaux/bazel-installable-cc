"""
Module to bring together useful rules for convenient loading in other modules.
"""

load(":clang_tidy.bzl", "clang_tidy_internal")
load(":clang_format.bzl", "clang_format_internal")
load(":compile_commands.bzl", "compile_commands_internal")

clang_tidy = clang_tidy_internal

clang_format = clang_format_internal

compile_commands = compile_commands_internal
