# An example makefile to drive various bazel rules

INTERACTIVE_SHELL:=$(shell [ -t 0 ] && echo 1)
ifdef INTERACTIVE_SHELL
BANNER_START:=$(shell printf "# \e[36m\e[1m‣ ")
BANNER_END:=$(shell printf "\e[0m")
else
BANNER_START:=$(shell printf "# ‣ ")
BANNER_END:=
endif
RECIPETAIL:=echo

PROJECT_NAME:=example
OUTPUT_BASE:=$(HOME)/.cache/bazel/_bazel_$(USER)/$(PROJECT_NAME)

debug:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel build --config=debug //example/...
	@$(RECIPETAIL)

release:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel build --config=release //example/...
	@$(RECIPETAIL)

asan:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel build --config=asan //example/...
	@$(RECIPETAIL)

ubsan:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel build --config=ubsan //example/...
	@$(RECIPETAIL)

tsan:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel build --config=tsan //example/...
	@$(RECIPETAIL)

compile_commands:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bin/generate_compile_commands.sh --config=compdb //example/...
	@$(RECIPETAIL)

static_analysis:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel build --config=static_analysis :static_analysis
	@$(RECIPETAIL)

format_check:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	#bazel --output_base=$(OUTPUT_BASE)/format_check run :buildifier_check
	bin/run_clang_format.sh --check --config=llvm //example/...
	@$(RECIPETAIL)

format_fix:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bin/run_clang_format.sh --fix --config=llvm //example/...
	bazel --output_base=$(OUTPUT_BASE)/format_fix   run --spawn_strategy=standalone :buildifier_fix
	bazel --output_base=$(OUTPUT_BASE)/format_check run --spawn_strategy=standalone :buildifier_check
	@$(RECIPETAIL)

