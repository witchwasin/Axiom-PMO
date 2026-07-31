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
  #
  # The sidecar is mandatory, not merely checked-if-present. `if (Test-Path
  # $sidecarPath)` was the first FATAL/MAJOR-class gap Independent AI Reviewer's review found in
  # this file: deleting the sidecar skipped the tamper check entirely rather
  # than failing closed, which is a strictly easier bypass than the
  # rewrite-both-files attack the code comment above already documents as a
  # known limit. A missing approved-digest record is exactly as unverifiable
  # as a missing contract (EXEC-002 above) -- there is no approved version to
  # compare against, so there is nothing to verify.
  $sidecarPath = "$ContractPath.sha256"
  if (-not (Test-Path -LiteralPath $sidecarPath -PathType Leaf)) {
    Add-Result FAIL "No digest sidecar found for the execution contract ($sidecarPath). Without the digest recorded at export time, there is no approved version to check the contract against -- a missing sidecar is treated the same as a missing contract, not as an unverified pass." "EXEC-002" -Artifact "EXECUTION-CONTRACT.json.sha256" -ItemId $verdict.work_item_id
    $verdict.verdict = "contract_digest_missing"
    return [pscustomobject]$verdict
  }
  # Get-Content -Raw on a zero-byte file returns $null (not an empty
  # string), and -- confirmed by direct repro, not assumed -- casting that
  # particular null with [string](...) does not reliably produce a normal
  # .NET string on this host either: `$x -is [string]` came back $false for
  # it even though it printed as empty. An explicit $null check, rather than
  # a cast, is what actually handles this safely.
  $sidecarRaw = Get-Content -LiteralPath $sidecarPath -Raw
  $sidecarText = if ($null -eq $sidecarRaw) { "" } else { $sidecarRaw.Trim().ToLowerInvariant() }
  if ($sidecarText -notmatch '^[0-9a-f]{64}$') {
    Add-Result FAIL "The digest sidecar ($sidecarPath) does not contain a well-formed SHA-256 digest." "EXEC-002" -Artifact "EXECUTION-CONTRACT.json.sha256" -ItemId $verdict.work_item_id
    $verdict.verdict = "contract_digest_malformed"
    return [pscustomobject]$verdict
  }
  if ($sidecarText -ne $contract.Digest) {
    Add-Result FAIL "The execution contract's contents no longer match the digest recorded when it was exported. The contract was modified after approval." "EXEC-002" -Artifact "EXECUTION-CONTRACT.json" -ItemId $verdict.work_item_id -Field "contract_sha256"
    $verdict.verdict = "contract_tampered"
    return [pscustomobject]$verdict
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

  # Repo-root-relative path of this project's decision-log.md, computed once
  # here so section 8 (EXEC-007) can check whether it falls inside the
  # observed changed-file set -- i.e. whether the execution under
  # verification touched the very log a human-authority claim cites. $null
  # when the project path is not actually inside $GitRepoRoot (an unusual
  # setup this check simply does not apply to; it degrades to "cannot tell",
  # never to a false pass).
  $decisionLogRelPath = $null
  $decisionLogFullPath = Join-Path $ProjectPath "decision-log.md"
  $normalizedGitRoot = $GitRepoRoot.TrimEnd('/', '\')
  if ($decisionLogFullPath.StartsWith($normalizedGitRoot, [System.StringComparison]::Ordinal)) {
    $decisionLogRelPath = $decisionLogFullPath.Substring($normalizedGitRoot.Length).TrimStart('/', '\') -replace '\\', '/'
  }

  # The result's own changed_files list is a claim; the diff is evidence.
  # Checked in both directions -- Independent AI Reviewer's review noted the original only checked
  # one:
  #
  #   observed, not claimed -- the more important direction. An undeclared
  #   change is exactly what a result would omit if it were hiding something,
  #   so it is reported even though the scope check below would also catch it
  #   when the path falls outside allowed_paths.
  #
  #   claimed, not observed -- a false claim. Not a scope bypass (scope is
  #   decided from the git-observed set, never from this list), but a result
  #   naming a file git shows no evidence of touching is a result asserting
  #   something that did not happen, which this milestone's whole premise is
  #   about catching regardless of which direction it points.
  if ($doc.PSObject.Properties["changed_files"]) {
    $claimedPaths = @($doc.changed_files | ForEach-Object { [string]$_ })
    foreach ($observed in $observedPaths) {
      if ($claimedPaths -cnotcontains $observed) {
        Add-Result FAIL "A file changed between the approved base and the reported head is not declared in the result's changed_files: $observed" "EXEC-008" -Artifact $observed -ItemId $verdict.work_item_id -Field "changed_files"
      }
    }
    $observedSet = @($observedPaths | Select-Object -Unique)
    foreach ($claimed in $claimedPaths) {
      if ([string]::IsNullOrWhiteSpace($claimed)) { continue }
      if ($observedSet -cnotcontains $claimed) {
        Add-Result FAIL "The result's changed_files claims a file that git shows no evidence of changing between the approved base and the reported head: $claimed" "EXEC-008" -Artifact $claimed -ItemId $verdict.work_item_id -Field "changed_files"
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
  #
  # Two independent questions per entry, and collapsing them is what let the
  # same defect ship twice:
  #
  #   Does the artifact check out?  -> Test-EvidenceEntryVerified. Opens the
  #                                    JUnit file and rehashes it, queries the
  #                                    GitHub API, reopens the sealed run
  #                                    record. Real work, not field presence.
  #   Does it prove WHO ran it?     -> $match.Provenance, from policy.
  #
  # Round 1 of review caught the first question not being asked at all. Round
  # 2 caught the second: the runner-exit-record check was doing real work --
  # containment, digest recomputation, contract binding, exit code -- on a
  # file that lives under .execution/**, which the verified actor can write
  # and which is exempt from scope analysis. A reviewer demonstrated a fully
  # hand-forged record with a genuinely matching sidecar passing, without the
  # runner ever being invoked.
  #
  # The correction is not a better check on the file. No check on a file the
  # actor can write proves who wrote it: a digest proves integrity since it
  # was taken and says nothing about provenance, and `sealed_by:
  # "axiom-runner"` is a string the forger types. So artifact-observed
  # evidence no longer satisfies a required test by itself. It takes either
  # an externally-observed source the actor cannot impersonate (today:
  # ci-check), or a human explicitly accepting responsibility for the
  # artifact on the record.
  #
  # That human path deliberately reuses the existing authority mechanism
  # rather than adding a config flag: a `test-evidence-accepted` claim from
  # actor `human`, citing a decision record that resolves in decision-log.md
  # and was not introduced by this execution's own commits (the same
  # conditions section 8 enforces for every human-only claim). A weakening
  # that is per-execution, attributable, and reviewable in a governed
  # artifact beats one that is a boolean in a config file.

  $evidence = Resolve-TestEvidenceEntries -Result $doc -Policy $policy

  # Which provenance tiers clear a required test on their own, read from
  # policy rather than hard-coded, so adding a genuinely external adapter
  # later is a config change.
  $satisfyingTiers = @()
  if ($policy.PSObject.Properties["evidence_provenance"]) {
    foreach ($tierProp in $policy.evidence_provenance.PSObject.Properties) {
      if ($tierProp.Name -eq "_note") { continue }
      if ([bool]$tierProp.Value.satisfies_required_test) { $satisfyingTiers += $tierProp.Name }
    }
  }

  # Has a human vouched for artifact-observed evidence on this execution?
  # Section 8 below independently validates and reports on every authority
  # claim; this only reads whether a valid vouch is present, so a bad vouch
  # produces one EXEC-007 there rather than a duplicate diagnostic here.
  $humanVouchType = "test-evidence-accepted"
  if ($policy.PSObject.Properties["required_test_satisfaction"] -and
      -not [string]::IsNullOrWhiteSpace([string]$policy.required_test_satisfaction.human_vouch_claim_type)) {
    $humanVouchType = [string]$policy.required_test_satisfaction.human_vouch_claim_type
  }
  $humanVouched = $false
  if ($doc.PSObject.Properties["authority_claims"]) {
    foreach ($claim in @($doc.authority_claims)) {
      if ([string]$claim.type -ne $humanVouchType) { continue }
      if ([string]$claim.actor -ne "human") { continue }
      $vouchRef = $null
      if ($claim.PSObject.Properties["decision_ref"]) { $vouchRef = [string]$claim.decision_ref }
      if ([string]::IsNullOrWhiteSpace($vouchRef)) { continue }
      $vouchResolved = Resolve-DecisionRecord -ProjectPath $ProjectPath -DecisionRef $vouchRef
      if (-not $vouchResolved.Found) { continue }
      # Same self-forgery guard as section 8: a decision the execution's own
      # commits could have written is not independent authority for it.
      if ($decisionLogRelPath -and ($observedPaths -contains $decisionLogRelPath)) { continue }
      $humanVouched = $true
      break
    }
  }

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

      $verification = Test-EvidenceEntryVerified -Entry $match -ProjectPath $ProjectPath -GitRepoRoot $GitRepoRoot -ContractSha256 $contract.Digest -WorkItemId $verdict.work_item_id
      if (-not $verification.Verified) {
        $unverified.Add($requiredName) | Out-Null
        Add-Result FAIL "A test the contract requires is not backed by verified evidence -- its '$($match.Type)' entry did not verify: $($verification.Reason). An agent's own assertion that a test passed is a claim, not evidence." "EXEC-005" -Artifact "EXECUTION-RESULT.json" -ItemId $requiredName -Field "test_evidence"
        continue
      }

      # The artifact checks out. Now: does it prove who produced it?
      if (($satisfyingTiers -notcontains $match.Provenance) -and (-not $humanVouched)) {
        $unverified.Add($requiredName) | Out-Null
        Add-Result FAIL "A test the contract requires is backed only by '$($match.Type)' evidence, which is $($match.Provenance): the artifact is well-formed and matches its declared digest, but it lives where the actor being verified can write it, so nothing here establishes who produced it -- a digest proves the file has not changed since it was hashed, never that a test ran. Satisfy this with evidence from a source the actor cannot impersonate (a ci-check), or have a human accept the artifact on the record with a '$humanVouchType' authority claim citing a decision record." "EXEC-005" -Artifact "EXECUTION-RESULT.json" -ItemId $requiredName -Field "test_evidence"
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
        } else {
          # Resolved for real, not just checked for non-emptiness: this used
          # to accept "DEC-999-NOT-REAL" outright. See
          # execution-contract-schema.ps1's Resolve-DecisionRecord docstring
          # for the exact contract.
          $resolved = Resolve-DecisionRecord -ProjectPath $ProjectPath -DecisionRef $decisionRef
          if (-not $resolved.Found) {
            $violations.Add("authority:$claimType") | Out-Null
            Add-Result FAIL "A human-only authority claim ('$claimType') cites decision record '$decisionRef', which could not be resolved: $($resolved.Reason). A citation that does not resolve to a real, unique row is not authority." "EXEC-007" -Artifact "EXECUTION-RESULT.json" -ItemId $claimType -Field "authority_claims.decision_ref"
          } elseif ($decisionLogRelPath -and ($observedPaths -contains $decisionLogRelPath)) {
            # The decision record exists -- but decision-log.md was itself
            # changed within the exact commit range this verification is
            # checking. A row the execution's own commits could have added or
            # edited is not independent of the thing it is supposed to
            # authorize; it is the agent writing its own permission slip.
            $violations.Add("authority:$claimType") | Out-Null
            Add-Result FAIL "A human-only authority claim ('$claimType') cites decision record '$decisionRef', but decision-log.md was itself changed within the commit range under verification. A decision the execution's own commits could have introduced cannot serve as independent human authority for that same execution." "EXEC-007" -Artifact "decision-log.md" -ItemId $claimType -Field "authority_claims.decision_ref"
          }
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
