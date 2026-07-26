# Ordinal string sorting for anything a machine compares.
#
# Sort-Object compares strings using the *current culture*. That is right for
# presentation and wrong for two things this framework does:
#
#   - a freshness digest, which must be byte-identical on every machine;
#   - a diagnostic's message order, which is compared against a golden master
#     captured on some other machine.
#
# Culture-aware collation deprioritises punctuation and folds case, so
# "decision-log.md" and "DELIVERY.md" order differently under it than under an
# ordinal sort -- and, in principle, differently between two cultures. This was
# not theoretical: switching the review-input digest from Sort-Object to
# ordinal changed its value, which means the two orderings genuinely differed.
#
# Every sort whose output reaches a digest or a diagnostic goes through here.

function Sort-Ordinal {
  param([string[]]$Values)

  if ($null -eq $Values -or $Values.Count -eq 0) { return @() }
  $copy = [string[]]::new($Values.Count)
  [Array]::Copy($Values, $copy, $Values.Count)
  [Array]::Sort($copy, [System.StringComparer]::Ordinal)
  return $copy
}

function Sort-OrdinalUnique {
  param([string[]]$Values)

  $unique = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@($Values), [System.StringComparer]::Ordinal)
  return (Sort-Ordinal -Values ([string[]]@($unique)))
}
