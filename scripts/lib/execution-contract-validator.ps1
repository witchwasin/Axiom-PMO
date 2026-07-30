# Execution-contract verification orchestration (M5.2/M5.3).
#
# Combines execution-contract-schema.ps1 (what the two documents say),
# execution-contract-git.ps1 (what the repository shows actually happened),
# and scope-diff-matcher.ps1's glob engine (whether a path was approved) into
# the same structured diagnostics every other check in this framework emits,
# through the same Add-Result accumulator. No new validation engine: this is
# one more caller of the existing one.
#
# Reading order matches the trust model in
# docs/architecture/execution-contract-verification.md:
#
#   1. Is the contract intact?          (EXEC-002)  -- nothing else means
#                                                      anything if it isn't
#   2. Is the result well-formed?       (EXEC-001)
#   3. Does it answer THIS contract?    (EXEC-003)
#   4. Can git confirm the claim?       (EXEC-008)
#   5. Did it stay inside scope?        (EXEC-004)
#   6. Is required-test evidence real?  (EXEC-005)
#   7. Did it exceed granted authority? (EXEC-006)
#   8. Did it try to approve itself?    (EXEC-007)
#
# Checks 3-8 are deliberately not short-circuited on each other's failure: a
# result that deviates on scope AND claims an approval it cannot grant should
# report both, because a human triaging it needs the whole picture, not the
# first thing that went wrong.

function Invoke-ExecutionContractVerification {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][string]$ResultPath,
    # Where the git history lives. Separate from $FrameworkRoot for the same
    # reason SCOPE-DIFF's is (see validate-project.ps1's -ScopeDiffRepoRoot):
    # when this runs as an Action, the framework checkout and the repository
    # under verification are different directories.
    [Parameter(Mandatory = $true)][string]$GitRepoRoot,
    [Parameter(Mandatory = $true)][string]$FrameworkRoot,
    # Defaults to the sibling EXECUTION-CONTRACT.json next to the result --
    # the layout `axiom export` produces. Overridable so a caller can verify a
    # result against a contract stored elsewhere (a release archive, say).
    [string]$ContractPath = $null
  )

  $resolvedResultPath = $ResultPath
  if (-not $ContractPath) {
    $ContractPath = Join-Path (Split-Path -Parent $resolvedResultPath) "EXECUTION-CONTRACT.json"
  }
  $policy = Read-ExecutionContractPolicy -FrameworkRoot $FrameworkRoot

  $verdict = [ordered]@{
    contract_path = $ContractPath
    result_path = $resolvedResultPath
    work_item_id = $null
    contract_sha256 = $null
    base_sha = $null
    head_sha = $null
    observed_commit_count = 0
    changed_files_observed = @()
    changed_files_out_of_scope = @()
    unverified_required_tests = @()
    authority_violations = @()
    verdict = "fail"
  }

  # --- 1. Contract intact (EXEC-002) ---------------------------------------

  $contract = Read-ExecutionContract -Path $ContractPath
  if (-not $contract.Present) {
    Add-Result FAIL "No execution contract found at the expected location. A result cannot be verified without the approved contract it claims to satisfy -- there is nothing to check it against." "EXEC-002" -Artifact "EXECUTION-CONTRACT.json"
    $verdict.verdict = "contract_missing"
    return [pscustomobject]$verdict
  }
  if (-not $contract.Valid) {
    Add-Result FAIL "Execution contract is invalid: $($contract.Error)" "EXEC-002" -Artifact "EXECUTION-CONTRACT.json"
    $verdict.verdict = "contract_invalid"
    return [pscustomobject]$verdict
  }
  $verdict.contract_sha256 = $contract.Digest
  $verdict.work_item_id = [string]$contract.Document.work_item_id
  $verdict.base_sha = [string]$contract.Document.base_sha

  # The sidecar digest is written at export time, before any agent runs, and
  # is what a human reviewing the export approved. Checking the live contract
  # against it catches the case the result alone cannot: an agent that edited
  # the contract to fit the work it actually did, then pointed its own
  # result at the edited version. (An agent that rewrites contract, sidecar,
  # and result consistently is not caught here -- only git history shows that.
  # Stated plainly in docs/reference/execution-contract.md rather than
  # implied to be covered.)
  $sidecarPath = "$ContractPath.sha256"
  if (Test-Path -LiteralPath $sidecarPath -PathType Leaf) {
    $sidecarText = (Get-Content -LiteralPath $sidecarPath -Raw).Trim().ToLowerInvariant()
    if ($sidecarText -ne $contract.Digest) {
      Add-Result FAIL "The execution contract's contents no longer match the digest recorded when it was exported. The contract was modified after approval." "EXEC-002" -Artifact "EXECUTION-CONTRACT.json" -ItemId $verdict.work_item_id -Field "contract_sha256"
      $verdict.verdict = "contract_tampered"
      return [pscustomobject]$verdict
    }
  }

  # --- 2. Result well-formed (EXEC-001) ------------------------------------

  $result = Read-ExecutionResult -Path $resolvedResultPath
  if (-not $result.Present) {
    Add-Result FAIL "No execution result found at the supplied path." "EXEC-001" -Artifact "EXECUTION-RESULT.json"
    $verdict.verdict = "result_missing"
    return [pscustomobject]$verdict
  }
  if (-not $result.Valid) {
    Add-Result FAIL "Execution result is invalid: $($result.Error)" "EXEC-001" -Artifact "EXECUTION-RESULT.json"
    $verdict.verdict = "result_invalid"
    return [pscustomobject]$verdict
  }
  $doc = $result.Document

  # --- 3. Answers this contract (EXEC-002 digest, EXEC-003 identity) -------

  if ([string]$doc.contract_sha256 -ne $contract.Digest) {
    Add-Result FAIL "The execution result answers a different version of the contract than the one on disk. Its contract_sha256 does not match the approved contract's digest." "EXEC-002" -Artifact "EXECUTION-RESULT.json" -ItemId $verdict.work_item_id -Field "contract_sha256"
    $verdict.verdict = "contract_mismatch"
    return [pscustomobject]$verdict
  }

  if ([string]$doc.work_item_id -ne [string]$contract.Document.work_item_id) {
    Add-Result FAIL "The execution result names a different work item than the contract it claims to satisfy." "EXEC-003" -Artifact "EXECUTION-RESULT.json" -ItemId ([string]$doc.work_item_id) -Field "work_item_id"
  }

  if ([string]$doc.base_sha -ne [string]$contract.Document.base_sha) {
    Add-Result FAIL "The execution result reports a different base commit than the contract approved. Work that did not start from the approved base is not the work that was approved." "EXEC-003" -Artifact "EXECUTION-RESULT.json" -ItemId $verdict.work_item_id -Field "base_sha"
  }

  # Requirement drift: a result may satisfy fewer requirements than approved
  # (partial work is a legitimate, declarable state) but may never introduce
  # one the contract does not list -- that is scope expansion by another name.
  $contractRequirements = @()
  if ($contract.Document.PSObject.Properties["requirement_refs"]) {
    $contractRequirements = @($contract.Document.requirement_refs | ForEach-Object { [string]$_ })
  }
  if ($doc.PSObject.Properties["requirement_refs"]) {
    foreach ($req in @($doc.requirement_refs)) {
      $reqText = [string]$req
      if ($contractRequirements -notcontains $reqText) {
        Add-Result FAIL "The execution result claims a requirement the contract does not cover: $reqText" "EXEC-003" -Artifact "EXECUTION-RESULT.json" -ItemId $reqText -Field "requirement_refs"
      }
    }
  }

  # --- 4. Git ground truth (EXEC-008) --------------------------------------

  $headRef = [string]$doc.head_sha
  if ([string]::IsNullOrWhiteSpace($headRef)) {
    Add-Result FAIL "The execution result does not report a head commit, so nothing it claims can be checked against the repository." "EXEC-008" -Artifact "EXECUTION-RESULT.json" -ItemId $verdict.work_item_id -Field "head_sha"
    $verdict.verdict = "unverifiable"
    return [pscustomobject]$verdict
  }

  $observation = Get-ExecutionGitObservation -RepoRoot $GitRepoRoot -BaseRef ([string]$contract.Document.base_sha) -HeadRef $headRef
  if (-not $observation.Ok) {
    Add-Result FAIL "Could not verify the execution result against git: $($observation.ErrorDetail)" "EXEC-008" -Artifact "EXECUTION-RESULT.json" -ItemId $verdict.work_item_id
    $verdict.verdict = "git_error"
    return [pscustomobject]$verdict
  }
  $verdict.base_sha = $observation.BaseSha
  $verdict.head_sha = $observation.HeadSha
  $verdict.observed_commit_count = $observation.CommitCount

  if (-not $observation.HeadDescendsFromBase) {
    Add-Result FAIL "The head commit the result reports does not descend from the contract's approved base commit." "EXEC-008" -Artifact "EXECUTION-RESULT.json" -ItemId $verdict.work_item_id -Field "head_sha"
  }

  # Paths the policy exempts from scope analysis: the contract, its digest
  # sidecar, and the result are governance bookkeeping committed for the audit
  # trail, so they necessarily appear in the diff being verified. Counting
  # them as unapproved implementation would make every verification fail on
  # its own artifacts -- found by the first end-to-end run of this code, not
  # reasoned about in advance. They stay in scope for EXEC-006 (committing a
  # bookkeeping file is still a commit).
  $exemptRegexes = @()
  if ($policy.PSObject.Properties["verification_exempt_paths"]) {
    $exemptRegexes = @($policy.verification_exempt_paths | ForEach-Object { ConvertTo-ScopeGlobRegex -Pattern ([string]$_.pattern) })
  }
  function Test-ExemptPath {
    param([string]$Path, $Regexes)
    foreach ($rx in $Regexes) {
      if ($Path -cmatch $rx) { return $true }
    }
    return $false
  }

  $observedPaths = New-Object System.Collections.Generic.List[string]
  foreach ($change in $observation.Changes) {
    $path = [string]$change.Path
    if (-not (Test-ExemptPath -Path $path -Regexes $exemptRegexes)) {
      $observedPaths.Add($path) | Out-Null
    }
    if ($change.OldPath) {
      $oldPath = [string]$change.OldPath
      if (-not (Test-ExemptPath -Path $oldPath -Regexes $exemptRegexes)) {
        $observedPaths.Add($oldPath) | Out-Null
      }
    }
  }
  $verdict.changed_files_observed = $observedPaths.ToArray()

  # The result's own changed_files list is a claim; the diff is evidence. A
  # file the agent changed but did not declare is the interesting direction --
  # an undeclared change is exactly what a result would omit if it were hiding
  # something, so it is reported even though the scope check below would also
  # catch it when it falls outside allowed_paths.
  if ($doc.PSObject.Properties["changed_files"]) {
    $claimedPaths = @($doc.changed_files | ForEach-Object { [string]$_ })
    foreach ($observed in $observedPaths) {
      if ($claimedPaths -cnotcontains $observed) {
        Add-Result FAIL "A file changed between the approved base and the reported head is not declared in the result's changed_files: $observed" "EXEC-008" -Artifact $observed -ItemId $verdict.work_item_id -Field "changed_files"
      }
    }
  }

  # --- 5. Scope (EXEC-004) -------------------------------------------------

  $allowedRegexes = @($contract.Document.allowed_paths | ForEach-Object { ConvertTo-ScopeGlobRegex -Pattern $_ })
  $prohibitedRegexes = @()
  if ($contract.Document.PSObject.Properties["prohibited_paths"]) {
    $prohibitedRegexes = @($contract.Document.prohibited_paths | ForEach-Object { ConvertTo-ScopeGlobRegex -Pattern $_ })
  }

  $outOfScope = New-Object System.Collections.Generic.List[string]
  foreach ($path in ($observedPaths | Select-Object -Unique)) {
    # -cmatch, never -match: same case-sensitivity reasoning as
    # scope-diff-matcher.ps1's Resolve-ScopeVerdict. A path differing only in
    # case is a different path on a case-sensitive checkout, and treating it
    # as approved would be a scope bypass.
    $prohibited = $false
    foreach ($rx in $prohibitedRegexes) {
      if ($path -cmatch $rx) { $prohibited = $true; break }
    }
    if ($prohibited) {
      $outOfScope.Add($path) | Out-Null
      Add-Result FAIL "A changed file matches a path the contract explicitly prohibited: $path" "EXEC-004" -Artifact $path -ItemId $verdict.work_item_id -Field "prohibited_paths"
      continue
    }

    $allowed = $false
    foreach ($rx in $allowedRegexes) {
      if ($path -cmatch $rx) { $allowed = $true; break }
    }
    if (-not $allowed) {
      $outOfScope.Add($path) | Out-Null
      Add-Result FAIL "A changed file is outside the paths the contract approved: $path" "EXEC-004" -Artifact $path -ItemId $verdict.work_item_id -Field "allowed_paths"
    }
  }
  $verdict.changed_files_out_of_scope = $outOfScope.ToArray()

  # --- 6. Required-test evidence (EXEC-005) --------------------------------

  $evidence = Resolve-TestEvidenceEntries -Result $doc -Policy $policy
  $unverified = New-Object System.Collections.Generic.List[string]
  if ($contract.Document.PSObject.Properties["required_tests"]) {
    foreach ($required in @($contract.Document.required_tests)) {
      $requiredName = [string]$required
      $match = $null
      foreach ($entry in $evidence) {
        if ($entry.Name -eq $requiredName) { $match = $entry; break }
      }

      if (-not $match) {
        $unverified.Add($requiredName) | Out-Null
        Add-Result FAIL "A test the contract requires has no evidence entry in the result at all: $requiredName" "EXEC-005" -Artifact "EXECUTION-RESULT.json" -ItemId $requiredName -Field "test_evidence"
        continue
      }
      if (-not $match.Verifiable) {
        $unverified.Add($requiredName) | Out-Null
        $detail = "its evidence is '$($match.Type)', which Axiom-PMO cannot independently verify"
        if ($match.MissingFields.Count -gt 0) {
          $detail = "its '$($match.Type)' evidence is missing the field(s) that would make it verifiable: $($match.MissingFields -join ', ')"
        }
        Add-Result FAIL "A test the contract requires is not backed by verifiable evidence -- $detail. An agent's own assertion that a test passed is a claim, not evidence." "EXEC-005" -Artifact "EXECUTION-RESULT.json" -ItemId $requiredName -Field "test_evidence"
      }
    }
  }
  $verdict.unverified_required_tests = $unverified.ToArray()

  # --- 7. Git authority (EXEC-006) -----------------------------------------

  $authority = $contract.Document.git_authority
  $violations = New-Object System.Collections.Generic.List[string]

  function Test-GrantedAction {
    param($Authority, [string]$Action)
    if (-not $Authority) { return $false }
    $prop = $Authority.PSObject.Properties[$Action]
    if (-not $prop) { return $false }
    return [bool]$prop.Value
  }

  # Observed, not claimed: commits existing between base and head is evidence
  # a commit happened, regardless of whether the result admits to it.
  if ($observation.CommitCount -gt 0 -and -not (Test-GrantedAction -Authority $authority -Action "commit")) {
    $violations.Add("commit") | Out-Null
    Add-Result FAIL "The repository shows $($observation.CommitCount) commit(s) between the approved base and the reported head, but the contract did not grant commit authority." "EXEC-006" -Artifact "EXECUTION-CONTRACT.json" -ItemId $verdict.work_item_id -Field "git_authority.commit"
  }

  # HeadOnRemote is tri-state on purpose. $true means a remote-tracking ref
  # contains this commit, which is real evidence of a push. $false and $null
  # both mean "not observed here", and neither is treated as proof a push did
  # not happen -- see this milestone's stated verification limits.
  if ($observation.HeadOnRemote -eq $true -and -not (Test-GrantedAction -Authority $authority -Action "push")) {
    $violations.Add("push") | Out-Null
    Add-Result FAIL "The reported head commit is present on a remote-tracking ref, but the contract did not grant push authority." "EXEC-006" -Artifact "EXECUTION-CONTRACT.json" -ItemId $verdict.work_item_id -Field "git_authority.push"
  }

  # Self-reported actions are checked too: a result that admits to an action
  # the contract withheld is a violation even when this checkout cannot
  # independently observe it.
  if ($doc.PSObject.Properties["git_actions_performed"]) {
    foreach ($action in @($doc.git_actions_performed)) {
      $actionText = [string]$action
      if ([string]::IsNullOrWhiteSpace($actionText)) { continue }
      if (-not (Test-GrantedAction -Authority $authority -Action $actionText)) {
        if ($violations -notcontains $actionText) { $violations.Add($actionText) | Out-Null }
        Add-Result FAIL "The result reports performing a git action the contract did not grant: $actionText" "EXEC-006" -Artifact "EXECUTION-RESULT.json" -ItemId $verdict.work_item_id -Field "git_actions_performed"
      }
    }
  }

  # --- 8. Authority claims / self-approval (EXEC-007) ----------------------

  if ($doc.PSObject.Properties["authority_claims"]) {
    foreach ($claim in @($doc.authority_claims)) {
      $claimType = [string]$claim.type
      $actor = [string]$claim.actor
      if ([string]::IsNullOrWhiteSpace($claimType)) { continue }

      $actorPolicy = $null
      if ($policy.actor_authority.PSObject.Properties[$actor]) {
        $actorPolicy = $policy.actor_authority.PSObject.Properties[$actor].Value
      }

      if (-not $actorPolicy) {
        $violations.Add("authority:$claimType") | Out-Null
        Add-Result FAIL "The result carries an authority claim from an unrecognized actor type '$actor'. An actor the policy does not know cannot be granted any authority." "EXEC-007" -Artifact "EXECUTION-RESULT.json" -ItemId $claimType -Field "authority_claims"
        continue
      }

      $mayGrant = @($actorPolicy.may_grant | ForEach-Object { [string]$_ })
      if ($mayGrant -notcontains $claimType) {
        $violations.Add("authority:$claimType") | Out-Null
        Add-Result FAIL "The result claims '$claimType' authority as actor '$actor', which is not authorized to grant it. An execution agent cannot approve its own work." "EXEC-007" -Artifact "EXECUTION-RESULT.json" -ItemId $claimType -Field "authority_claims"
        continue
      }

      # A human-only claim asserted inside an agent-authored file is only as
      # good as the governed record it points at. Requiring a decision_ref
      # means the claim is anchored to decision-log.md, which a human is
      # accountable for -- rather than to a string the agent typed.
      $typePolicy = $null
      if ($policy.authority_claim_types.PSObject.Properties[$claimType]) {
        $typePolicy = $policy.authority_claim_types.PSObject.Properties[$claimType].Value
      }
      if ($typePolicy -and [bool]$typePolicy.human_only) {
        $decisionRef = $null
        if ($claim.PSObject.Properties["decision_ref"]) { $decisionRef = [string]$claim.decision_ref }
        if ([string]::IsNullOrWhiteSpace($decisionRef)) {
          $violations.Add("authority:$claimType") | Out-Null
          Add-Result FAIL "A human-only authority claim ('$claimType') cites no decision record. Commit authorship alone does not prove a human actor; the claim must reference a DEC-### in decision-log.md." "EXEC-007" -Artifact "EXECUTION-RESULT.json" -ItemId $claimType -Field "authority_claims.decision_ref"
        }
      }
    }
  }
  $verdict.authority_violations = $violations.ToArray()

  # --- verdict --------------------------------------------------------------

  $failed = ($script:messages | Where-Object { $_.level -eq "FAIL" -and $_.rule_id -like "EXEC-*" }).Count
  if ($failed -eq 0) {
    Add-Result PASS "Execution result verified against the approved contract and observed git state: $($observation.CommitCount) commit(s), $(@($observedPaths | Select-Object -Unique).Count) changed file(s), all within approved scope." "EXEC-001"
    $verdict.verdict = "pass"
  }

  return [pscustomobject]$verdict
}
