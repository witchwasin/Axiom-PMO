// Core shared types for the Node/TypeScript interpreter.
//
// Field order in the diagnostic row and envelope mirrors result-writer.ps1
// exactly: JSON.stringify preserves insertion order, and the golden masters
// compare JSON bytes canonically, so a reordered object is a golden diff.
export const DIAGNOSTICS_SCHEMA_VERSION = "1.1";
