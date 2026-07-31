# Writing validator code that survives every supported host

> For anyone — human or agent — **writing or changing PowerShell under
> `scripts/`**. For installing a runtime, see
> [`docs/guides/powershell-runtime.md`](../guides/powershell-runtime.md).

Axiom-PMO's required hosts are Windows PowerShell 5.1, PowerShell 7 on
Windows, PowerShell 7 on Linux, and PowerShell 7 on macOS
([Milestone 3.5](../../ROADMAP.md)). Code that works on one is not code that
works on four, and the differences are not exotic — they are ordinary
constructs that behave differently, silently, in ways a local test run on a
developer's Mac cannot reveal.

Every entry below **caused a real, shipped defect in this repository**, most
of them caught by CI on a leg the author could not run locally. They are
recorded here because the same failure recurring is the actual risk: the
CRLF-crash pitfall (§1) was found, fixed in a test file, and then written
*again* into product code two commits later, because the lesson lived only in
a commit message.

If you are about to write a native command call, a JSON comparison, or a
file read in `scripts/`, read the matching section first.

---

## 1. Native command stderr is a terminating error under `Stop` (5.1 only)

**The rule:** in Windows PowerShell 5.1, when `$ErrorActionPreference` is
`"Stop"`, *any* output a native command writes to stderr becomes a
**terminating error** — even a purely informational message, and even when
you redirect with `2>$null`. PowerShell 7 does not do this.

**Why it keeps happening:** the redirect *looks* like it handles the problem.
`& git ... 2>$null` reads as "discard stderr", and on the host most people
develop on, it does exactly that.

**What it broke, three times:**

| Where | The stderr that killed it |
|---|---|
| `tests/helpers/execution-contract-tests.ps1` | `git add` printing "LF will be replaced by CRLF" |
| `Test-CiCheckEvidence` | `git remote get-url origin` printing "error: No such remote 'origin'" on a repo with no remote — the whole verification script died before emitting any JSON, so a user got a crash instead of an "unverified" verdict |
| `scripts/run-execution-command.ps1` | *Any* test command that writes to stderr while passing — `npm`, `pytest`, and `jest` all do. An ordinary green test suite would have crashed the runner before it sealed a record. |

The third was never caught by tests, because every fixture command in the
suite was `echo ok` or `exit 1` — neither writes to stderr. It was found by
auditing for the pattern after the second one, not by a failing test.

**Do this:**

```powershell
$previousEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $output = & git -C $repo remote get-url origin 2>$null
  $exitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousEap
}
```

`scripts/lib/execution-contract-evidence.ps1` wraps this as
`Invoke-NativeCapture`; reuse it rather than open-coding another
save/restore that the next person has to recognise.

**Deliberate exceptions**, which the automated check below allowlists:

- `rev-parse --verify --quiet` — `--quiet` suppresses stderr by design.
- `2>$stderrFile` — redirecting to a real file is a different mechanism and
  does not raise. This is also the pattern to use when you need the stderr
  text for a log (see `scope-diff-git-adapter.ps1`).

---

## 2. `ConvertTo-Json` formats differently across hosts

Windows PowerShell 5.1 writes `"key":  value` — **two** spaces after the
colon. PowerShell 7 writes one. Property ordering can differ too.

**What it broke:** a test tampered with a contract by string-replacing the
literal `'"push": false'`. On 5.1 that matched nothing, so the file was never
modified, its digest correctly still matched, and verification correctly
returned pass — *the test failed while the product was right*.

**Do this:**

- Never string-match against serialized JSON. Parse it, edit the object,
  re-serialize.
- Never compute a digest by re-serializing. Hash the file's **stored bytes**
  (`Get-FileHash`). This is why `EXECUTION-CONTRACT.json` and every sealed
  run record use a `.sha256` sidecar of the file itself: a digest that
  disagrees across hosts would report tampering that did not happen.

---

## 3. `Get-Content -Raw` returns `$null` on a zero-byte file

Not `""` — `$null`. And `$null.Trim()` throws.

Worse, and confirmed by direct repro on PowerShell 7.6: casting *that
specific null* with a `[string]` cast does not reliably produce a usable
.NET string either — `$x -is [string]` came back `$false` for it.

**What it broke:** an adversarial test for an empty digest sidecar crashed
the whole verification run instead of reporting a malformed digest. The
`[string]` cast written as the first fix did not help.

**Do this:**

```powershell
$raw = Get-Content -LiteralPath $path -Raw
$text = if ($null -eq $raw) { "" } else { $raw.Trim() }
```

An explicit `$null` check, not a cast.

---

## 4. `Invoke-Expression` runs in *your* process

**What it broke:** the execution runner used `Invoke-Expression $Command`.
A command containing `exit 0` — perfectly ordinary in a test script —
terminated the runner itself, before the code that captured the exit code
and wrote the sealed record ever ran. The evidence silently vanished.

**Do this:** spawn a real child process (`& $shellExe @shellArgs`), so the
command's own `exit` ends only the child. See
`scripts/run-execution-command.ps1`.

---

## 5. Case-insensitive matching is not a formatting detail

PowerShell's `-match` is **case-insensitive by default**. On a
case-sensitive checkout (Linux, macOS, most CI runners) `SRC/PAYMENTS/x.ts`
and `src/payments/x.ts` are different files.

**What it broke:** SCOPE-DIFF's path matching accepted a wrong-case path as
in-scope — a real scope bypass, found in review, not by tests.

**Do this:** use `-cmatch` for any comparison against a repository path.
When testing this, inject the case-differing path through the git index
(`git hash-object` + `update-index --cacheinfo`) — writing it through the
working tree on a case-insensitive filesystem silently lands in the existing
directory and hides the bug.

---

## Enforcement, and the debt it does not cover

`DOCTOR-010` fails the build on an unguarded native invocation in a script
under `scripts/` that sets `"Stop"`. That is §1 turned into a check, so the
rule survives without anyone remembering it.

**It does not scan `tests/`, where roughly 50 equivalent sites exist.** Those
are real instances of the same class, not false positives, and they are
recorded here rather than quietly excluded. Two reasons for the scope:

1. **Consequence differs.** An unguarded call in a test harness crashes
   loudly in CI — annoying, but self-revealing within one run. The same call
   in product code crashes on a user's machine, on a host the maintainer
   cannot reproduce, and presents as the tool being broken.
2. **Churn risk.** Retrofitting ~50 sites across accepted, currently-green
   test files in the same change as a correctness fix would mix a large
   mechanical diff into a review that needs attention on the logic.

New or modified test code should still follow §1. The existing sites are
worth paying down as those files are touched for other reasons, not in one
sweep.

## Before you push

Local success on one host proves less than it feels like. The specific gap
that keeps mattering: **this project's own maintainer machine is macOS and
cannot run Windows PowerShell 5.1 at all.** Three of the defects above were
green locally and red in CI.

- Run `scripts/run-all-checks.ps1`, not just the suite you touched. That
  bundle includes `scripts/check-public-hygiene.ps1`, which has caught a
  real leak that per-suite runs missed.
- Expect the 5.1 leg to be the one that fails, and read its log rather than
  guessing a fix — a wrong guess costs a full CI round-trip. If a failure is
  not obvious from the log, add a diagnostic that prints the actual state
  and push *that* first.
- State plainly in the commit message when something is CI-verified only.
  "Tests pass" and "tests pass on every required host" are different claims.

## Related

- [`validation-engine.md`](validation-engine.md) — how the engine defends itself
- [`docs/guides/powershell-runtime.md`](../guides/powershell-runtime.md) — installing a host
- `DOCTOR-010` — the automated check that enforces §1

## 6. `$IsWindows` does not exist in Windows PowerShell 5.1

**Shipped in Milestone 6.** Caught by CI, not locally.

`$IsWindows` arrived with PowerShell Core. On Windows PowerShell 5.1 it is
`$null` — and 5.1 only ever runs on Windows. So every natural spelling of "not
Windows" is true *on Windows*:

```powershell
if ($IsWindows -ne $true)  { }   # TRUE on 5.1
if (-not $IsWindows)       { }   # TRUE on 5.1
if ($null -eq $IsWindows)  { }   # TRUE on 5.1, usually written to mean "Unix"
```

On PowerShell 7 all three are correct, so nothing looks wrong on the host this
repository is written on.

The Milestone 6.3 and 6.5 suites guarded their symlink and `chmod` cases this
way. Both ran on Windows PowerShell 5.1, where `ln -s` and `chmod` do not
exist. The `chmod` case is the more dangerous of the two: it fails silently and
then reports a pass for a read-only scenario it never created.

**Use `Test-WindowsHost`** from `scripts/lib/pwsh-host.ps1`, which checks
`$PSVersionTable.PSEdition` first. Enforced by
[`DOCTOR-011`](../rules/DOCTOR-011.md) across both `scripts/` and `tests/`.
