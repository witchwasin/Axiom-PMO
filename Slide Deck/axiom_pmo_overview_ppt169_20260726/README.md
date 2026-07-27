# axiom_pmo_overview

- Canvas format: ppt169
- Created: 20260726

## Directories

- `svg_output/`: raw SVG output
- `svg_final/`: self-contained SVG visual preview; may be inserted manually as an SVG image, but PowerPoint Convert to Shape is unsupported
- `images/`: runtime image pool; converter assets keep their original short filenames when possible
- `icons/`: project icon set — selected library icons copied in (via icon_sync.py) plus any custom icons you add; embedded from here at export
- `notes/`: speaker notes
- `templates/`: project templates
- `live_preview/`: browser preview runtime files and history (lock.json, server.log, edits.jsonl, annotations.jsonl)
- `sources/`: source materials and normalized markdown
- `analysis/`: machine-extracted intermediate analysis (PPTX intake, image_analysis.csv) — the pipeline's canonical must-read source/asset facts
- `validation/`: SVG quality reports and PPTX postflight audit reports
- `exports/`: final native DrawingML pptx deliverables only (timestamped); `_native_charts_tables.pptx` name with `--native-charts-and-tables`, `_narrated.pptx` name when narration audio is embedded
- `backup/<timestamp>/`: svg_output/ archive (always written in default-flow mode; safe to delete old timestamps)

## Brand Assets

The deck ships a starter brand identity for Axiom-PMO in `images/`:

- `axiom-pmo-logo-primary.svg` — primary logo for general presentation and documentation use
- `axiom-pmo-mark.svg` — the Axiom Gate mark for compact placements
- `axiom-pmo-logo-monochrome.svg` — single-color variant for low-contrast backgrounds
- `axiom-pmo-slide-signature.svg` — header/footer lockup for slide headers and footers

The brand board (positioning, palette, typography, dark-background application) is available as:

- `images/axiom-pmo-brand-board-en.svg`
- `images/axiom-pmo-brand-board.svg`
