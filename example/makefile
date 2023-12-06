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

OUTPUT_BASE:=$(shell tools/print_output_base.sh)
COMPILER:=--config=gcc13

debug:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel --output_base=$(OUTPUT_BASE)/debug build $(COMPILER) --config=debug //src/... //config/...
	@$(RECIPETAIL)

release:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel --output_base=$(OUTPUT_BASE)/release build $(COMPILER) --config=release //src/... //config/...
	@$(RECIPETAIL)

asan:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel --output_base=$(OUTPUT_BASE)/asan build $(COMPILER) --config=asan //src/... //config/...
	@$(RECIPETAIL)

ubsan:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel --output_base=$(OUTPUT_BASE)/ubsan build $(COMPILER) --config=ubsan //src/... //config/...
	@$(RECIPETAIL)

tsan:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel --output_base=$(OUTPUT_BASE)/tsan build $(COMPILER) --config=tsan //src/... //config/...
	@$(RECIPETAIL)

compile_commands:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	tools/lint/refresh.sh compile_commands //src/... //config/...
	@$(RECIPETAIL)

static_analysis:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	tools/lint/refresh.sh static_analysis //src/... //config/...
	@$(RECIPETAIL)

format_check:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	tools/lint/refresh.sh clang_format check //src/... //config/...
	bazel --output_base=$(OUTPUT_BASE)/buildifier run :buildifier_check
	@$(RECIPETAIL)

format_fix:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	tools/lint/refresh.sh clang_format fix //src/... //config/...
	bazel --output_base=$(OUTPUT_BASE)/buildifier run :buildifier_check
	bazel --output_base=$(OUTPUT_BASE)/buildifier run --spawn_strategy=standalone :buildifier_fix
	bazel --output_base=$(OUTPUT_BASE)/buildifier run --spawn_strategy=standalone :buildifier_check
	@$(RECIPETAIL)

