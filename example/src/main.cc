/**
 * Copyright (c) 2023 Broadcom.  All
 * rights reserved.
 */

#include "some_lib.h"

#include <fmt/format.h>

#include <cstdio>
#include <cstdlib>

// NOLINTNEXTLINE(bugprone-exception-escape)
int main(int, char**) {
  fmt::print("Hello world, {}\n", Cple::BazelTest::some_string());
  return EXIT_SUCCESS;
}
