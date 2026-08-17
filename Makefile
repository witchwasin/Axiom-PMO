# Axiom-PMO convenience targets.
#
# These wrap the Node implementation; they do not reimplement any validation
# logic. Phase 9: the PowerShell reference was deleted, so every target runs
# the Node CLI (cli/axiom.mjs) or the Node test runner directly.

NODE ?= node

.PHONY: demo doctor validate test mutation contract eol assess handoff e2e cli check clean-room help

help:
	@echo "Targets:"
	@echo "  demo      Three-minute proof: a broken handoff, then a fixed one"
	@echo "  check     Everything below, in order"
	@echo "  doctor    Framework health"
	@echo "  test      Full Node unit-test suite"
	@echo "  validate  Validation fixtures against the committed golden masters"
	@echo "  mutation  Config-is-source-of-truth tests"
	@echo "  contract  Structured diagnostics contract tests"
	@echo "  eol       Line-ending (CRLF vs LF) regression tests"
	@echo "  assess    Handoff readiness assessment tests"
	@echo "  handoff   Handoff gate on the worked example"
	@echo "  e2e       Generator-to-gate end-to-end runs"
	@echo "  cli       Thin CLI tests"
	@echo "  clean-room  Build the clean-room walkthrough container (see clean-room/)"

demo:
	$(NODE) cli/axiom.mjs demo

doctor:
	$(NODE) cli/axiom.mjs doctor

validate:
	$(NODE) dist/tools/run-ci-suite-cli.js -Suite validation-fixtures -RepoPath .

test:
	$(NODE) --test $$(find dist -name '*.test.js' | sort)

mutation:
	$(NODE) --test dist/tools/config-mutation.test.js

contract:
	$(NODE) --test dist/output/diagnostics-contract.test.js

eol:
	$(NODE) --test dist/output/line-ending.test.js

assess:
	$(NODE) --test dist/tools/assess-handoff.test.js

handoff:
	$(NODE) cli/axiom.mjs validate --project examples/HANDOFF-DEMO --mode Standard --gate Handoff --fail-on-warning
	$(NODE) cli/axiom.mjs handoff --project examples/HANDOFF-DEMO --mode Standard

e2e:
	$(NODE) --test dist/tools/e2e.test.js

cli:
	$(NODE) tests/helpers/cli-tests.mjs

# Not part of `check`: this builds an environment for a person to walk through,
# not a test to run. See clean-room/README.md for what it can and cannot prove.
CONTAINER ?= docker
PREREQS ?= none
clean-room:
	$(CONTAINER) build --build-arg PREREQS=$(PREREQS) -t axiom-cleanroom:$(PREREQS) clean-room
	@echo ""
	@echo "Run it:  $(CONTAINER) run --rm -it axiom-cleanroom:$(PREREQS)"

check:
	$(NODE) cli/axiom.mjs check
