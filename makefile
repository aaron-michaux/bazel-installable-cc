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
	#	bin/generate_compile_commands.sh --config=compdb //example/...
	bazel --output_base=$(OUTPUT_BASE)/tool build --config=compdb :compile_commands
	rm -f compile_commands.json
	ln -s bazel-bin/compile_commands.json compile_commands.json
	@$(RECIPETAIL)

static_analysis:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	bazel build --config=static_analysis :static_analysis
	@$(RECIPETAIL)

format_check:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	tools/target_lists/refresh.sh
	bazel --output_base=$(OUTPUT_BASE)/tool build --config=llvm :format_check
	bazel --output_base=$(OUTPUT_BASE)/buildifier run :buildifier_check
	@$(RECIPETAIL)

format_fix:
	@echo "$(BANNER_START)$@$(BANNER_END)"
	tools/target_lists/refresh.sh
	bazel --output_base=$(OUTPUT_BASE)/tool build --spawn_strategy=standalone --config=llvm :format_fix
	bazel --output_base=$(OUTPUT_BASE)/buildifier run --spawn_strategy=standalone :buildifier_fix
	bazel --output_base=$(OUTPUT_BASE)/buildifier run --spawn_strategy=standalone :buildifier_check
	@$(RECIPETAIL)

