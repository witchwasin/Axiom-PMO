# Clean-room walkthrough environment

A container that carries none of your machine's state, so you can follow the
README as a stranger would and find out where it fails them.

Tracks [issue #8](https://github.com/witchwasin/Axiom-PMO/issues/8).

> **Status: unverified.** This Dockerfile has not been built. The machine it was
> written on has a Docker CLI pointing at another user's socket and no container
> runtime available. The external URLs it depends on were checked and resolve;
> the build itself has not run. Treat the first build as part of the
> walkthrough — if it fails, that is finding number one.

---

## Why

Everything about this project has been verified by people who already knew the
answer. That is the weakest possible evidence for a getting-started experience,
and `ROADMAP.md` names a clean-room walkthrough as a Milestone 1 exit criterion.

The failure mode being hunted is not a crash. It is the sentence that assumes
you already know something: a prerequisite that is named but not explained, a
command that needs a flag the example omits, a path that only works from the
repository root.

## Two modes

The build argument decides which question you are asking.

```bash
cd clean-room

# "Can the docs get a stranger running at all?"
docker build --build-arg PREREQS=none -t axiom-cleanroom:none .
docker run --rm -it axiom-cleanroom:none

# "If you install exactly what the docs ask for, does it work?"
docker build --build-arg PREREQS=documented -t axiom-cleanroom:documented .
docker run --rm -it axiom-cleanroom:documented
```

| Mode | Contains | Finds |
|---|---|---|
| `none` *(default)* | `git`, `curl` | Missing or wrong install instructions |
| `documented` | Above plus PowerShell 7 and Node.js — exactly what `README.md` names | Gaps in the usage instructions |

`podman` works the same way; substitute `podman` for `docker`.

## What to do inside

The container prints a briefing on login and then gets out of the way. In short:

1. `git clone https://github.com/witchwasin/Axiom-PMO.git`
2. Follow `README.md` from the top. Do not skip ahead.
3. Write down every point of friction. Small ones count — they are what a
   first-time reader actually hits.

**Do not read the source to work out what a command should have done.** If the
documentation did not tell you, that is the finding. Reading the code to
recover is exactly the move a real newcomer cannot make, and doing it here
converts a real gap into an invisible one.

To walk your working copy instead of the published one:

```bash
docker run --rm -it -v "$(pwd)/..":/home/walker/Axiom-PMO:ro axiom-cleanroom:none
```

Read-only on purpose: a walkthrough that edits the repository is no longer a
walkthrough.

## What this cannot prove

**It is Linux.** Windows PowerShell 5.1 is the reference platform for this
project; Ubuntu PowerShell 7 is now a blocking CI leg and macOS PowerShell 7 is
recorded as non-blocking evidence (Milestone 3.5). A clean walk in this
container is useful Linux evidence for issue #8 and nothing more.

Whoever reports findings should say which platform they walked. "The
walkthrough passed" without that qualifier is the kind of claim this project
exists to prevent.

Windows needs a Windows machine, or a Windows container image, which is a
separate piece of work.

## The machine-checkable half

One question in issue #8 does not need a human: *does installing exactly the
documented prerequisites suffice to run the documented first command?*

```bash
docker build --build-arg PREREQS=documented -t axiom-cleanroom:documented .
docker run --rm axiom-cleanroom:documented bash -lc '
  git clone --depth 1 https://github.com/witchwasin/Axiom-PMO.git >/dev/null 2>&1 &&
  cd Axiom-PMO &&
  node cli/axiom.mjs demo >/dev/null 2>&1 &&
  echo "documented prerequisites are sufficient" ||
  echo "documented prerequisites are NOT sufficient"
'
```

This is worth wiring into CI once it has been shown to work. It is **not** a
substitute for the human walkthrough: it proves the happy path executes, not
that a person could have found it.

## Reporting

Put findings on [#8](https://github.com/witchwasin/Axiom-PMO/issues/8). Useful
shape:

```text
Platform:     Linux container, PREREQS=none
Step:         README Quick start, second command
Expected:     a new project under projects/
Got:          "The term 'pwsh' is not recognized"
Gap:          README names PowerShell as a prerequisite but never links an
              install page; the CLI error does, but only if you reach the CLI
Suggested:    link the install pages from the prerequisite sentence
```

Then fix the docs. A finding without a documentation change is a note, not a
closed issue.
