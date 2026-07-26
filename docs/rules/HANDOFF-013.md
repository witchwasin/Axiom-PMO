# HANDOFF-013 - Table header does not match the declared columns

| | |
|---|---|
| Level | FAIL |
| Gate | Handoff |
| Applies to | Lite, Standard, Strict |
| Artifacts | `HANDOFF.md`, `DESIGN/BUILD-SPEC.md` |

## What this rule checks

Every governed table's header row matches the columns declared for it in
`pmo-config/handoff-policy.json` — `handoff_document.sections[].columns` and
`build_spec.sections[].columns` — by name and in order.

A table that is absent entirely is not this rule's finding; `HANDOFF-002` and
`HANDOFF-005` cover that.

## Why it blocks

The validator reads cells **by column name**. Rename `Blocking Point` to
`Blocking`, and `$row.'Blocking Point'` resolves to an empty string — no error,
just nothing there.

The gate then reports:

```text
[FAIL] HANDOFF-009 Open action OA-001 has no valid blocking point
```

which is true of the parsed data and misleading about the cause. The author
looks at the row, sees `before_demo` written plainly in it, and concludes the
validator is broken. That is worse than a missing check: it spends the reader's
trust on a diagnostic that points at the wrong thing.

Asserting the header converts a confusing downstream symptom into one accurate
statement about the actual mistake.

## Order matters

The columns are declared as an ordered list, and a reader moving between two
projects should find the same shape in both. A reordered header is reported
separately from a renamed one, because the fix is different:

```text
Table 'Open Actions' has the declared columns in a different order
  (expected: Action ID | Description | Owner | Blocking Point | Status)

Table 'Open Actions' header does not match the declared columns
  (missing: Blocking Point; unexpected: Blocking)
```

Set `table_headers.order_matters` to `false` if a project genuinely needs
freedom here — but consider first whether the reader benefits from that freedom.

## What the validator does not do

It does not check the *contents* of any cell, and it does not check tables whose
columns the policy does not declare. Column counts inside `templates/` are a
different check (`TABLE-001`).

## How to fix

Restore the header from the policy. To see what is expected:

```bash
python3 -c "import json;d=json.load(open('pmo-config/handoff-policy.json'));
print([s['columns'] for s in d['handoff_document']['sections'] if s.get('table')])"
```

## Related

`HANDOFF-002`, `HANDOFF-005` (the table exists at all), `TABLE-001` (column
counts in framework templates).
