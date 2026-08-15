// Typed, per-run ValidationContext (CR-012). The PowerShell implementation used
// `$script:` module globals to share state across dot-sourced modules; the port
// must not. Every run gets its own context object threaded through every
// validator call, so sequential and concurrent multi-project runs cannot leak
// state or caches into each other.
export function createAccumulator() {
    return { messages: [], pass: 0, warn: 0, warnBlocking: 0, fail: 0 };
}
export function createEnvelope(ctx, requestedMode, effectiveMode, gate, exitCode) {
    const a = ctx.accumulator;
    const envelope = {
        schema_version: "1.1",
        project: ctx.project,
        requested_mode: requestedMode,
        effective_mode: effectiveMode,
        gate,
        summary: {
            pass: a.pass,
            warn: a.warn,
            warn_blocking: a.warnBlocking,
            fail: a.fail,
            exit_code: exitCode,
        },
        results: a.messages,
    };
    if (ctx.scopeDiff !== null) {
        envelope.scope_diff = ctx.scopeDiff;
    }
    return envelope;
}
