// Trivial child-process fixture used by run-all-checks.ts's fault-injection
// step to prove a failing check actually propagates. Node equivalent of the
// deleted exit-1.ps1 (1 line, `exit 1`).
process.exit(1);
