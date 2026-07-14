# Axiom-PMO convenience targets.
#
# These wrap the PowerShell reference implementation; they do not reimplement any
# validation logic. PWSH defaults to `pwsh` (PowerShell 7). On Windows PowerShell
# 5.1, override it:  make check PWSH=powershell
#
# Linux/macOS execution via pwsh is EXPERIMENTAL.

PWSH ?= pwsh
PS := $(PWSH) -NoProfile -ExecutionPolicy Bypass -File

.PHONY: doctor validate test golden mutation e2e check help

help:
	@echo "Targets: doctor validate test golden mutation e2e check"

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

e2e:
	$(PS) tests/e2e/lite.ps1 -RepoPath .
	$(PS) tests/e2e/standard.ps1 -RepoPath .
	$(PS) tests/e2e/strict.ps1 -RepoPath .

check:
	$(PS) scripts/run-all-checks.ps1 -RepoPath .
