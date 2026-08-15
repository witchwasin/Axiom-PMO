// Ordinal string sorting for anything a machine compares, ported from
// scripts/lib/ordinal-sort.ps1. JS Array.prototype.sort's default is
// UTF-16 code-unit order, which is NOT ordinal (it's also not culture-aware),
// so we sort with a code-point compare to match .NET StringComparer.Ordinal.

function compareOrdinal(a: string, b: string): number {
  const len = Math.min(a.length, b.length);
  for (let i = 0; i < len; i++) {
    const ca = a.codePointAt(i)!;
    const cb = b.codePointAt(i)!;
    if (ca < cb) return -1;
    if (ca > cb) return 1;
    // Handle surrogate pairs: codePointAt returns the full code point, so
    // incrementing by the UTF-16 length avoids double-counting surrogates.
    const aWidth = ca > 0xffff ? 2 : 1;
    const bWidth = cb > 0xffff ? 2 : 1;
    i += Math.max(aWidth, bWidth) - 1;
  }
  return a.length - b.length;
}

export function sortOrdinal(values: string[]): string[] {
  if (!values || values.length === 0) return [];
  return [...values].sort(compareOrdinal);
}

export function sortOrdinalUnique(values: string[]): string[] {
  const unique = Array.from(new Set(values));
  return sortOrdinal(unique);
}
