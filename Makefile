

SHELL ?= /usr/bin/bash


.PHONY: test test_log_sh test_utils_sh
test: test_log_sh test_utils_sh


test_log_sh:
	source log.sh; run_unit_test

test_utils_sh:
	source log.sh; source utils.sh; run_unit_test
