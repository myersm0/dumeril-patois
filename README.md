# dumeril-patois

[![CI](https://github.com/myersm0/dumeril-patois/actions/workflows/ci.yml/badge.svg)](https://github.com/myersm0/dumeril-patois/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/myersm0/dumeril-patois)](https://github.com/myersm0/dumeril-patois/releases/latest)

Structured edition of Édélestand and Alfred Du Méril, ***Dictionnaire du patois normand*** (Caen: B. Mancel, 1849). Page scans from the [Internet Archive](https://archive.org/details/dictionnairedupa00dumuoft); structured output via vision-LLM OCR and a custom parser. Available as TEI Lex-0 XML and SQLite.

Norman is a Romance language of northwestern France. The Du Méril _Dictionnaire_ records 19th-century rural Norman speech, with etymologies tracing words back to Old French, Latin, Old Norse, and Greek.

> **Status:** work in progress. Check back soon.

## Downloads

Pre-built data products will be attached to each [GitHub release](../../releases) once stage 5 lands:

| File | Description | Size |
|------|-------------|------|
| `dumeril.tei.xml.gz` | TEI Lex-0 XML, all entries | TBD |
| `dumeril.db.gz` | SQLite database for computational queries | TBD |

## What this provides

The 1849 print is in the public domain, but the OCR distributed with it (Internet Archive djvu) is too garbled to be usable for any purpose more demanding than full-text keyword search — and even then, only barely. Compare a single entry, **Abo** ("a wooden hobble for livestock"), as rendered by the two pipelines:

**From the existing Internet Archive OCR:**

```
Auo,  s.  m.  Morceau  de  bois
(|ue  l'on  attache  au  pied  des
chevaux  pour  les  emjjècher  de
j)asser  d'un  champ  dans  un  au-
tre. Saint  Jérôme  disait  déjà  :
Fac  lihi  vincula  et  calenas  l'sive
y.'/.cirjç,  qui  hebraice  appellan-
tur  Mothoth,  et  sermone  vul-
gari  Boias  vocant);  In  Ifierc-
miam,  I.  V.  ch.  27,
```

Garbled headword (`Auo` for `Abo`), broken Latin (`lihi` for `tibi`, `calenas` for `catenas`), Greek lost entirely (`y.'/.cirjç` for `κλοιους`), no italicization, hyphenation breaks not reflowed.

**From this pipeline:**

> **Abo**, s. m. Morceau de bois que l'on attache au pied des chevaux pour les empêcher de passer d'un champ dans un autre. Saint Jérôme disait déjà : Fac tibi vincula et catenas (sive <gr>κλοιους</gr>, qui hebraice appellantur *Mothoth*, et sermone vulgari *Boias* vocant); *In Hieremiam*, l. V, ch. 27,

Headword marked as small caps, Latin and Greek correctly transcribed, italics preserved on cited foreign words and work titles, line breaks reflowed.

## Enrichments over the source

Beyond accurate transcription, the pipeline produces:

- **Typography preservation** — italics, small caps, and Greek script captured inline at OCR time rather than reconstructed.
- **Layout reflow** — cross-page hyphenation joined; mid-page column-header catchwords (which appear at the top of *each* column, not just the page) stripped and surrounding text rejoined.
- **Entry segmentation** — POS-anchored detection of dictionary entries, tolerant of multi-word headwords (`ACAM et CAM`), locutions (`ABOULEZ-CI-GAU`), and the print convention by which large initial caps lose their diacritics (`EGRIMER` ↔ `Égrimer`).
- **Structured fields** — part of speech, regional usage label, gloss, etymology, source citations, and embedded quotations extracted from each entry body.
- **Cross-reference resolution** — `Voyez X`-style cross-references resolved to entry IDs via a normalized headword index.
- **Headword normalization** — a `headword_normalized` field (lowercase, diacritic-stripped) bridges accent and case variation across the volume.
- **Two output formats** — TEI Lex-0 XML for scholarly use and interchange, SQLite for computational queries.

## TEI structure

Entries sit inside a `<body xml:lang="fr">` container and follow roughly this pattern:

```xml
<entry xml:id="abo" type="mainEntry">
  <form type="lemma"><orth>Abo</orth></form>
  <gramGrp>
    <gram type="pos">s.</gram>
    <gram type="gender">m.</gram>
  </gramGrp>
  <sense xml:id="abo.1">
    <def>Morceau de bois que l'on attache au pied des chevaux
         pour les empêcher de passer d'un champ dans un autre.</def>
    <cit type="example">
      <quote>Fac tibi vincula et catenas (sive
        <foreign xml:lang="grc">κλοιους</foreign>,
        qui hebraice appellantur <foreign xml:lang="la">Mothoth</foreign>,
        et sermone vulgari <foreign xml:lang="la">Boias</foreign> vocant)</quote>
      <bibl>
        <author>Saint Jérôme</author>,
        <title>In Hieremiam</title>, l. V, ch. 27
      </bibl>
    </cit>
  </sense>
  <etym>
    <cit type="etymon" xml:lang="la">
      <form><orth>Boias</orth></form>
    </cit>
  </etym>
  <xr type="related"><ref type="entry" target="#abuisser">Abuisser</ref></xr>
</entry>
```

## SQLite schema

The database provides a flat, queryable view:

- **entries** — headword (raw + normalized), POS, region, body text, page number, flags
- **etymologies** — language, etymon, script, gloss, parent entry
- **citations** — author (raw + resolved), work title, locator (page, column, verse), parent entry
- **quotations** — quoted text, parent citation
- **cross_references** — surface form, normalized target, resolved target entry id
- **intro_entries** — etymologies from the introduction (separate schema, simpler)
- **footnotes** — marker, body, page
- **pages** — section, source text per page (so the database is self-contained)

Example queries:

```sql
-- All entries borrowed from Old Norse
SELECT e.headword_raw, et.etymon, et.gloss
FROM entries e JOIN etymologies et ON et.entry_id = e.id
WHERE et.language = 'islandais';

-- All entries citing the Roman de Rou
SELECT DISTINCT e.headword_raw
FROM entries e JOIN citations c ON c.entry_id = e.id
WHERE c.work_title = 'Roman de Rou';

-- Cross-references into the letter A
SELECT from_e.headword_raw, xr.surface_form, to_e.headword_raw
FROM cross_references xr
JOIN entries from_e ON xr.from_entry_id = from_e.id
JOIN entries to_e ON xr.to_entry_id = to_e.id
WHERE to_e.headword_normalized LIKE 'a%';
```

## Pipeline

Five stages, each output reproducible from the one before it:

1. **Acquire.** Fetch JP2 page scans from the Internet Archive. → `data/raw/jp2/`
2. **Preprocess.** Convert JP2 to PNG; apply per-parity rotation and a fixed crop to remove the facing-page sliver. → temp PNGs
3. **OCR.** Send each cropped page to Claude Opus 4.7 with a transcription prompt that preserves italics, small caps, and Greek script. → `data/raw/ocr/opus/page_NNNN.md`
4. **Concatenate.** Strip column-header catchwords, reflow hyphenation across page and column boundaries, normalize all-caps small caps to sentence case, and split the volume into its intro and dictionary halves. → `build/intro.md`, `build/entries.md`
5. **Parse and emit.** Segment entries (POS-anchored), extract structured fields, resolve cross-references, write TEI XML and SQLite. → `build/dumeril.tei.xml`, `build/dumeril.db`

## Building from source

Requires Julia 1.10+, `sips` (macOS image conversion), `curl`, `tar`, and an `ANTHROPIC_API_KEY` environment variable.

```
scripts/acquire.sh
julia --project=. scripts/ocr.jl
julia --project=. bin/run_pipeline.jl
```

`run_pipeline.jl` orchestrates concatenate → parse → emit. The OCR stage is run separately because it is slow and expensive (~3 hours, ~$20 in API spend for 222 dictionary pages).

## Tests

Smoke tests for each pipeline stage:

```
julia --project=. test/smoke_concatenate.jl
julia --project=. test/smoke_parse.jl
julia --project=. test/smoke_tei.jl
julia --project=. test/smoke_sqlite.jl
```

## Repository structure

```
dumeril-patois/
├── Project.toml
├── README.md
├── LICENSE
├── src/
│   ├── DumerilPatois.jl     module root
│   ├── model.jl             type definitions
│   ├── preprocessing.jl     JP2 → cropped PNG
│   ├── ocr.jl               page → markdown via Opus
│   ├── concatenate.jl       per-page → intro.md / entries.md
│   ├── parse.jl             entries.md → structured Entry objects
│   ├── parse_intro.jl       intro.md → IntroEntry objects
│   ├── resolve.jl           cross-reference resolution
│   ├── emit_tei.jl          model → TEI Lex-0 XML
│   └── emit_sqlite.jl       model → SQLite
├── bin/
│   └── run_pipeline.jl      CLI orchestrator (stages 4–5)
├── scripts/
│   ├── acquire.sh
│   ├── ocr.jl               the expensive OCR run
│   └── ...                  experimental and ad-hoc tools
├── test/
│   ├── smoke_*.jl           per-stage smoke tests
│   └── fixtures/            synthetic test data
├── patches/
│   └── patches.toml         OCR corrections, line-targeted
├── config/
│   └── closed_sets.toml     POS, regions, etymology triggers
├── data/
│   ├── raw/jp2/             scans (not tracked)
│   └── raw/ocr/opus/        OCR markdown (not tracked)
├── build/                   pipeline outputs (not tracked; see Releases)
└── docs/
    └── schema.md            full SQLite schema reference
```

## Design notes

### OCR model selection

Several models were evaluated, including local Qwen 2.5-VL 32B and 72B via Ollama, and Claude Opus 4.7. I OCR'd a sample of pages with each, computed token-level diffs between Opus and Qwen, and hand-verified every disagreement against the page scan. Opus was correct in 100% of the dozens of disagreements reviewed. Beyond raw accuracy, Opus also preserves italics, small caps, and Greek script inline — the local LLM's were not able to do this.

### Post-OCR manual quality pass

After the bulk run completed, every page was reviewed for the `⟨?⟩` markers Opus emits where it cannot confidently read a glyph. This surfaced a few minor cropping issues and a few cases of characters that were truly indecipherable in the source images.

This pass helped to confirm transcription discipline: even when the missing character was overwhelmingly inferable from context (e.g. `fra⟨?⟩çais` for *français*), the model left the question mark rather than guessing. Spot-checks of pages adjacent to known crop-failure pages turned up no hallucinations.

Then, where context made the missing character near-certain, I reviewed the source images myself and manually fixed them myself when I could do so with sufficient confidence (e.g. in `ancienn⟨?⟩ signification` the missing letter can safely be assumed to be an 'e'). There were only a few cases where the source image was obscured beyond confident reconstruction, and I let the `⟨?⟩` markers remain in these cases.

### Strict certain-or-unclassified parsing

The entry parser follows a strict certainty regime borrowed from sibling project [deep-littre](https://github.com/myersm0/deep-littre): rules either match enough structural signal to be definitively right, or the candidate is left `unclassified` for downstream review. There is no confidence axis, no best-guessing. The `unclassified` set is queryable in both the TEI output (`<entry ana="unclassified">`) and SQLite, and serves as the working surface for follow-up — new tightened rules, LLM-assisted review, or manual inspection.

### Headword normalization

19th-century French typography drops diacritics from large-font initial caps because the print can't fit the accent above the larger glyph. The same lemma can therefore appear faithfully in two forms — `EGRIMER` as an entry headword and `Égrimer` in body cross-references — and the OCR is faithful to both. Resolution is via a `headword_normalized` field (lowercase, diacritic-stripped) used for matching at parse time, not by mutating either surface form.

### Cross-page reflow

Hyphenated splits (`Pei-` / `ne, Embarras`) are reflowed during concatenation. Mid-sentence breaks without hyphenation are not, in order to preserve the alignment between page markers and source text. The parser tolerates sentences that span page boundaries.

### Source patches

OCR corrections live in `patches/patches.toml` as line-targeted string replacements applied in memory during concatenation. Originals in `data/raw/ocr/opus/` stay untouched. Patches never add or remove lines, so source line numbers are stable identifiers — usable as keys for both targeted overrides and provenance metadata on every parsed item.

### LLM-assisted overrides (verdicts)

For structurally hard cases — chiefly quotation/attribution segmentation, where verse and prose quotations are interleaved with editorial commentary — the parser supports an optional verdicts CSV keyed on `(page, line)`. Verdicts override heuristic classification when present, but the heuristics still run first, so the verdict surface is small and targeted.

## Known limitations

- **Stages 4–5 incomplete.** Concatenation library exists; parser, TEI emitter, and SQLite emitter are scaffolded but not implemented.
- **TEI etymology shape is provisional.** The TEI Lex-0 Etymology chapter is currently a stub in the official spec, leaving the precise modeling of etymons, cognates, and explanatory prose underspecified. The current target uses `<cit type="etymon">` with nested `<form><orth>` based on extrapolation from the Forms and Cross-references chapters; this may need to migrate when Lex-0 publishes the etymology chapter.
- **Quotation segmentation.** The hardest structural feature — separating quoted passages from editorial prose with author/work attribution — is expected to land an `unclassified` bucket of nontrivial size at first parse, narrowed iteratively.

## Source data

This project builds directly on:

> *Dictionnaire du patois normand*, by Édélestand Du Méril and Alfred Du Méril.
> Caen: B. Mancel, 1849.
> Scans hosted by the [Internet Archive](https://archive.org/details/dictionnairedupa00dumuoft); original text in the public domain.

## Citing dumeril-patois

A paper describing this project is in preparation. In the meantime, if you use this dataset in published research, please cite:

```bibtex
@software{myers-dumeril-patois,
  author  = {Myers, Michael J.},
  title   = {dumeril-patois: A Structured Edition of the Du Méril Dictionnaire du patois normand},
  year    = {2026},
  url     = {https://github.com/myersm0/dumeril-patois},
  version = {0.1.0}
}
```

## License

CC-BY-SA 4.0. See [LICENSE](LICENSE).
