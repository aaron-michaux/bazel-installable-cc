/**
 * Copyright (c) 2023 Broadcom.  All rights reserved.
 */

#include "some_lib.h"

#include <fmt/format.h>

#include <cstdio>
#include <cstdlib>

int main(int, char**) {
  fmt::print("hello world, {}\n", Cple::BazelTest::some_string());
  return EXIT_SUCCESS;
}
