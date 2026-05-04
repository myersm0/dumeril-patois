# dumeril-patois

Structured edition of Édélestand and Alfred Du Méril, ***Dictionnaire du patois normand*** (Caen: B. Mancel, 1849). Page scans from the [Internet Archive](https://archive.org/details/dictionnairedupa00dumuoft); structured output via vision-LLM OCR and a custom parser.

Norman is a Romance language of northwestern France. The Du Méril _Dictionnaire_ records 19th-century rural Norman speech, with etymologies tracing words back to Old French, Latin, Old Norse, and Greek.

> **Status:** work in progress. Check back soon.

## What this enables

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

## Output

The end product is `build/patois.sqlite`, with one row per dictionary entry and normalized tables for cross-references, etymologies, citations, and quoted passages. This makes the dictionary queryable as structured data — for instance, "all entries borrowed from Old Norse," "all entries that cite *Roman de Rou*," or "all entries cross-referenced from somewhere in the letter A."

## Pipeline

Five stages, each output reproducible from the one before it:

1. **Acquire.** Fetch JP2 page scans from the Internet Archive. → `data/raw/jp2/`
2. **Preprocess.** Convert JP2 to PNG; apply per-parity rotation and a fixed crop to remove the facing-page sliver. → temp PNGs
3. **OCR.** Send each cropped page to Claude Opus 4.7 with a transcription prompt that preserves italics, small caps, and Greek script. → `data/raw/ocr/opus/page_NNNN.md`
4. **Concatenate.** Strip column-header catchwords (which appear at the top of *each* column, including mid-page on the right column), reflow hyphenation across page and column boundaries, normalize all-caps small caps to sentence case, and split the volume into its intro and dictionary halves. → `build/intro.md`, `build/dictionary.md`
5. **Parse.** Segment the dictionary into entries (POS-anchored), extract structured fields, resolve cross-references, write SQLite. → `build/patois.sqlite`

## Build

Requires Julia 1.10+, `sips` (macOS image conversion), `curl`, `tar`, and an `ANTHROPIC_API_KEY` environment variable.

```
scripts/acquire.sh
julia --project=. scripts/ocr.jl
julia --project=. scripts/concatenate.jl
julia --project=. scripts/parse.jl
julia --project=. scripts/build_db.jl
```

## Layout

```
src/                 library code (no I/O at top level)
scripts/             driver scripts
data/raw/jp2/        source page scans
data/raw/ocr/opus/   per-page OCR markdown
build/               concatenated and structured outputs
config/              closed sets (POS, regions, etymology triggers)
```

## Design notes

**OCR model selection.** Several models were evaluated, including local Qwen 2.5-VL 32B and 72B via Ollama, and Claude Opus 4.7. I OCR'd a sample of pages with each, computed token-level diffs between Opus and Qwen, and hand-verified every disagreement against the page scan. Opus was correct in 100% of the dozens of disagreements reviewed. Beyond raw accuracy, Opus also preserves italics, small caps, and Greek script inline — the local LLM's were not able to do this.

**Headword normalization.** 19th-century French typography drops diacritics from large-font initial caps because the print can't fit the accent above the larger glyph. The same lemma can therefore appear faithfully in two forms — `EGRIMER` as an entry headword and `Égrimer` in body cross-references — and the OCR is faithful to both. Resolution is via a `headword_normalized` field (lowercase, diacritic-stripped) used for matching at parse time, not by mutating either surface form.

**Cross-page reflow.** Hyphenated splits (`Pei-` / `ne, Embarras`) are reflowed during concatenation. Mid-sentence breaks without hyphenation are not, in order to preserve the alignment between page markers and source text. The parser tolerates sentences that span page boundaries.

## License

CC-BY-SA 4.0. See [LICENSE](LICENSE).
