# Axiom-PMO convenience targets.
#
# These wrap the PowerShell reference implementation; they do not reimplement any
# validation logic. PWSH defaults to `pwsh` (PowerShell 7). On Windows PowerShell
# 5.1, override it:  make check PWSH=powershell
#
# Linux/macOS execution via pwsh is EXPERIMENTAL.

PWSH ?= pwsh
PS := $(PWSH) -NoProfile -ExecutionPolicy Bypass -File
NODE ?= node

.PHONY: demo doctor validate test golden mutation contract assess handoff e2e cli check help

help:
	@echo "Targets:"
	@echo "  demo      Three-minute proof: a broken handoff, then a fixed one"
	@echo "  check     Everything below, in order"
	@echo "  doctor    Framework health"
	@echo "  test      Validation fixtures"
	@echo "  validate  Validation fixtures + golden master"
	@echo "  golden    Example golden outputs"
	@echo "  mutation  Config-is-source-of-truth tests"
	@echo "  contract  Structured diagnostics contract tests"
	@echo "  assess    Handoff readiness assessment tests"
	@echo "  handoff   Handoff gate on the worked example"
	@echo "  e2e       Generator-to-gate end-to-end runs"
	@echo "  cli       Thin CLI tests (requires Node.js)"

demo:
	$(PS) scripts/demo.ps1

doctor:
	$(PS) scripts/pmo-doctor.ps1

validate:
	$(PS) scripts/run-validation-tests.ps1 -RepoPath . -VerifyGolden

test:
	$(PS) scripts/run-validation-tests.ps1 -RepoPath .

golden:
	$(PS) tests/golden/capture-examples.ps1 -Verify

mutation:
	$(PS) tests/helpers/config-mutation-tests.ps1 -RepoPath .

contract:
	$(PS) tests/helpers/diagnostics-contract-tests.ps1 -RepoPath .

assess:
	$(PS) tests/helpers/handoff-assessment-tests.ps1 -RepoPath .

handoff:
	$(PS) scripts/validate-project.ps1 -ProjectPath examples/HANDOFF-DEMO -Mode Standard -Gate Handoff -FailOnWarning
	$(PS) scripts/assess-handoff.ps1 -ProjectPath examples/HANDOFF-DEMO -Mode Standard

e2e:
	$(PS) tests/e2e/lite.ps1 -RepoPath .
	$(PS) tests/e2e/standard.ps1 -RepoPath .
	$(PS) tests/e2e/strict.ps1 -RepoPath .
	$(PS) tests/e2e/handoff.ps1 -RepoPath .

cli:
	$(NODE) tests/helpers/cli-tests.mjs

check:
	$(PS) scripts/run-all-checks.ps1 -RepoPath .
