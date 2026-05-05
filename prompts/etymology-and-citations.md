You are extracting structured data from entries of an 1849 Norman patois dictionary (Du Méril, *Dictionnaire du patois normand*). Each entry has already been segmented; you receive the entry's body text and emit JSON.

# Output schema

Emit a single JSON object with exactly four top-level keys:

```json
{
  "etymologies": [...],
  "citations": [...],
  "cross_references": [...],
  "attestations": [...]
}
```

Any of the four arrays may be empty. Never omit a top-level key.

## etymology object

```json
{
  "language": "latin",
  "etymon": "Pastor",
  "gloss": "Berger, Pasteur",
  "hedge": null,
  "attribution": null,
  "surface_text": "du latin *Pastor*, qui s'est conservé dans *Pasteur* et *Pastoureau*"
}
```

- `language` — canonical ID from the closed set below. Use `null` if the language doesn't match any allowed value.
- `etymon` — the cited form. Strip italic markers (`*foo*` → `foo`) and Greek tags (`<gr>foo</gr>` → `foo`). Strip trailing punctuation (`Pastor,` → `Pastor`).
- `gloss` — the French translation/explanation of the etymon, if Du Méril supplies one. Otherwise `null`. (E.g. for `du grec <gr>Βουφαγος</gr>, qui mange un bœuf` the gloss is `qui mange un bœuf`.)
- `hedge` — one of `peut-être`, `plutôt`, `probablement`, `sans doute`, `vraisemblablement`, `apparemment`. `null` if the etymology is asserted without hedging.
- `attribution` — the third-party scholar Du Méril credits this etymology to (e.g. Borel, Roquefort, Huet, Ducange, Diez). `null` if Du Méril is asserting it himself.
- `surface_text` — the substring of the body text the etymology was extracted from, including the language preposition and any leading hedge. End at the natural sentence/clause boundary.

## citation object

```json
{
  "author": "Lalleman",
  "work": "La Campénade",
  "editor": null,
  "anthology": null,
  "locator": "ch. I, p. 9",
  "surface_text": "**Lalleman**, *La Campénade*, ch. I, p. 9."
}
```

- `author` — small-caps/bold author name, asterisks stripped. `null` for anonymous works or when no author is given.
- `work` — required. The cited work's title. Italic markers stripped. If the citation is `dans <Editor>, *<Anthology>*` shape with no other work named (i.e. the work is anonymous and only the anthology is identified), put the anthology in `work` and leave `anthology` null.
- `editor` — for the `*<Title>*, dans <Editor>, *<Anthology>*` shape, the name between `dans` and the anthology. `null` otherwise.
- `anthology` — for the same shape, the anthology title. `null` otherwise.
- `locator` — free-form string, preserved verbatim including punctuation. Combine compound locators (`ch. I, p. 9`, `t. ii, p. 307`, `l. V, ch. 27`). `null` if no locator given.
- `surface_text` — the attribution span only. **Do not include the quoted text** that the citation attributes; that's a separate downstream concern. Typically starts at the bold author or italic work title and ends at the final locator.

## cross_reference object

```json
{
  "surface_form": "bavolet",
  "normalized": "bavolet",
  "shape": "voy_bold"
}
```

- `surface_form` — the headword being referenced, as it appears in the source. Strip bold markers.
- `normalized` — lowercase + diacritics stripped (e.g. `Égrimer` → `egrimer`). For variant-target shapes (`le mot suivant`, `l'art. suivant`), keep the variant phrase verbatim and we'll resolve later.
- `shape` — one of:
  - `voy_bold` — `Voy. **X**` or `Voyez **X**`
  - `voy_variant` — textual variant without a bold target (`Voyez le mot suivant`, `Vo. l'art. précédent`)

## attestation object

```json
{
  "form": "Rue des Seulles",
  "kind": "phrase",
  "surface_text": "il y avait autrefois à Caen une rue appelée la *Rue des Seulles*"
}
```

- `form` — the italic phrase, asterisks stripped, trailing punctuation removed. No introducing phrase.
- `kind` — one of:
  - `variant` — italic spelling variant of the headword, typically introduced by `On dit aussi`, `On dit également`, `appelé aussi`, `se dit également`, `est aussi appelé`. The form is a single-word lexical alternative to the entry's headword.
  - `locution` — italic multi-word phrase that the entry is glossing as a fixed expression, often the entry-leading form (`*Se mettre à bondecul* signifie...`). Typically the headword appears inside it.
  - `phrase` — italic phrase quoted from real-world attestation (place names, fixed expressions, technical usages) demonstrating the headword in context. Use this when neither `variant` nor `locution` clearly applies.
- `surface_text` — the substring of the body text the attestation was extracted from, including enough surrounding context to ground it.

# Closed-set vocabularies

## Allowed `language` values

```
latin, bas_latin, old_french, french,
greek,
provencal, italian, spanish, portuguese, catalan, romansh, languedocian,
german, old_high_german, low_german, english, old_english, dutch, flemish, gothic, frankish,
old_norse,
breton, celtic, gaulish, irish, gaelic, basque,
arabic, hebrew
```

If the surface language doesn't map to one of these, emit `language: null` and still capture the etymon and surface_text. Do not invent new IDs.

## Surface-form → canonical ID hints (illustrative, not exhaustive)

```
"du latin", "en latin"            → latin
"du bas-latin", "en bas-latin",
"en basse-latinité"               → bas_latin
"du vieux-français",
"en vieux-français"               → old_french
"du français", "en français"      → french
"du grec"                         → greek
"de l'islandais", "en islandais",
"du norse", "en vieil-islandais"  → old_norse
"de l'anglais", "en anglais"      → english
"du vieil-anglais",
"en vieil-anglais",
"du saxon", "en saxon",
"de l'anglo-saxon",
"en anglo-saxon"                  → old_english
"du breton", "en breton",
"du bas-breton"                   → breton
... (etc.)
```

When in doubt, infer the canonical ID from the language family above. If genuinely unrecognized, use `null`.

# Extraction discipline (read carefully)

## Strict certain-or-omit

If you cannot identify a field with structural certainty, return `null` for that field — or, if the entire candidate is ambiguous, omit the candidate from the array. Better to under-extract than to guess. Downstream review handles missing extractions; it cannot recover from confidently-wrong ones.

## What counts as an etymology

**Etymons** are forms cited as the source of the headword via etymological prepositions:

- **Direct shape**: `(de l'|du |en )<lang> *<etymon>*` — e.g. `du latin *Pastor*`, `de l'islandais *Beita*`.
- **Inverse shape**: `*<form>* signifiait en <lang> *<etymon>*` — e.g. `*Virer* signifiait en vieux-français Lancer, Jeter`. Note: the form on the left is what Du Méril is glossing (often the headword or a related French word); the etymon is on the right.
- **Greek shape**: `du grec <gr>...</gr>` — set `language: "greek"` reliably.
- **Chained alternative shape**: when an etymon already extracted is followed by an alternative form introduced by a hedge (`plutôt`, `ou plutôt`, `ou peut-être`, `ou`) without restating the language, extract the alternative as a separate etymology with `language: null`. Set `hedge` to the connecting hedge word and capture etymon and gloss as usual. Example: in `plutôt de *Buffare*, Se gonfler de mangeaille, que du grec...`, the *Buffare* form lacks an explicit language but is the leading candidate in a chained pair where Du Méril is weighing alternatives.
- **Compound shape**: `(de l'|du |en )<lang> *<A>* et *<B>*` where both forms together are the etymological source — e.g. `de l'islandais *Hol* et *Land*`. Both forms extract as separate etymon entries, both with the same `language`. Distinguish from the disjunctive `*A* ou *B*` shape (alternatives, one etymon extracts).

## What does NOT count as an etymology

- **Cognate listings**: `*<form>* en italien`, `*<form>* en portugais`. These are evidence Du Méril cites; they are not etymons. Do not extract.
- **Preserved-in claims**: `dans l'<lang> *X*`, `s'est conservé dans l'<lang> *X*`. These are derivative forms, not sources. Do not extract.
- **Headword-meaning shape**: `ce mot signifiait en <lang> Y`, `<headword> signifiait en <lang> Y`. The text on the left is "this word"/the headword, not an italic form being glossed — Du Méril is reporting what the headword used to mean, not its etymology. Do not extract. (Distinguishing tell: real inverse shape has `*<italic_form>*` immediately before `signifiait`; headword-meaning has bare `ce mot` or a non-italic phrase.)
- **Morphological-category captures**: `du verbe *X*`, `du substantif *X*`, `du diminutif *X*`. The etymological language was upstream in the sentence; without it the form is not an extractable etymon. Do not extract.
- **Bare italic forms with no etymological framing.** An italic noun in body prose (`*Pasteur*`, `*Cellier*`, `*paitre*`) is not by itself an etymon. The chained-alternative shape above is the only path by which a `language: null` etymon legitimately enters the output; outside that shape, an italic form without an etymological preposition or hedge is body-text, not extraction.

## Scholar attribution overlap with citations

Some etymologies carry a scholarly attribution that also looks like a citation (e.g. `du latin *Pastor*, suivant Roquefort, t. ii, p. 314`). When the attributed scholar carries a locator, **extract twice**: once as `etymology.attribution` (with the etymon and language), once as a separate citation entry (with `author: "Roquefort"`, `work: null`, `locator: "t. ii, p. 314"`). The two extractions are independent and serve different downstream queries. If the attributed scholar has no locator (`auquel le rattache Borel`), set `attribution: "Borel"` on the etymology and emit nothing in citations.

## What counts as a citation

A citation is a formal attribution of a quoted text or referenced passage to an authored work, with a locator. The shapes:

- **Authored**: `**Author**, *Work*, locator.` (bold author, italic work, locator)
- **Anonymous**: `*Work*, locator.` (no author)
- **Anthology-wrapped**: `*Work*, dans <Editor>, *<Anthology>*, locator.` — original work + reprinting anthology + editor.
- **Mid-prose**: `*Work*, locator: ...` — work cited inline, often introducing a quotation that follows.

## Citation surface_text scope

The `surface_text` of a citation is the **attribution span only**: typically starts at the bold author or italic work title and ends at the final locator. **Do not** include the quoted passage that precedes the citation. The quotation is a separate item (handled downstream); conflating them here corrupts the citation output.

## Bold incipits ≠ work titles

When Du Méril cites an anonymous work, he sometimes bolds the *first line of the quotation itself* (the incipit) and follows it with `dans <Editor>, *<Anthology>*, locator`. In this case the bold span is the incipit, **not** the work title. Treat the anthology as `work`, the editor as `editor`, and leave `author` null. Set `anthology` to null because the anthology is acting as the work in this case.

Example:
```
**La volenteis dont mes cuers est ravis**, dans Wackernagel,
*Altfranzoesische Lieder*, p. 65.
```

→

```json
{
  "author": null,
  "work": "Altfranzoesische Lieder",
  "editor": "Wackernagel",
  "anthology": null,
  "locator": "p. 65",
  "surface_text": "dans Wackernagel, *Altfranzoesische Lieder*, p. 65."
}
```

The bold incipit goes nowhere in the citation output — it belongs to the quotation, not the citation.

## What does NOT count as a citation

- Mid-prose scholar mentions without a locator (e.g. "Roquefort prétend...", "selon Borel"). Those are references, not citations. **However**, if a locator IS present without a work title (e.g. "suivant Roquefort, t. ii, p. 314"), extract the citation with `work: null` — the locator carries enough structural signal to count, and Du Méril's reader is expected to infer the work.
- Mentions of works without a locator (e.g. "comme dans le *Roman de Rou*" with no page/verse). Edge case; if the locator is genuinely absent, set `locator: null` but the citation still extracts.
- Du Méril's own headword being italicized (which is not a work title).

## What counts as a cross-reference

`Voy. **X**`, `Voyez **X**` — emit shape `voy_bold`, capture the bold target.

`Voyez le mot suivant`, `Vo. l'art. précédent`, similar textual variants without a bold target — emit shape `voy_variant`, surface_form = the variant phrase verbatim.

## What counts as an attestation

Italic phrases in body prose that are neither etymons, cognates, citation work titles, nor cross-reference targets — they are attested *usages* of the headword in real-world context.

- **`variant`**: italic single-word spelling alternatives of the headword. Almost always introduced by phrases like `On dit aussi *X*`, `On dit également *X*`, `appelé aussi *X*`. Capture only the form; do not include the introducing phrase in `form`.

- **`locution`**: italic multi-word phrases the entry is glossing as a fixed expression. Typically the entry-leading construction (`*Se mettre à bondecul* signifie...`, `*Tomber en quenouille* veut dire...`) where Du Méril is defining the locution itself.

- **`phrase`**: phrases attested from the world — place names, titles or designations, fixed technical or proverbial usages — quoted to show the headword in context. Normally italicized (`*Rue des Seulles*`, `*Pont à la vieille*`, `*Sanctus Petrus de Vetula*`), but Du Méril omits italics on proper nouns introduced by an explicit historical-attestation framer; in that case the framer plus a capitalized form containing the headword is sufficient structural signal. Allowed framers: `on trouve dans de vieux actes`, `on lit dans <work>`, `dans une charte de`, `dans un acte de`, `mentionné dans`. Default when neither `variant` nor `locution` clearly applies.

## What does NOT count as an attestation

- **Etymons** (extracted as etymology).
- **Cognates** in other languages (`*Pastounadez* en bas-breton`, `*Boias* en vulgaire`).
- **Derived/related French forms** Du Méril mentions in passing (`*Pasteur* et *Pastoureau*` as French descendants of *Pastor*; `*Cellier* dont l'origine peut être la même`). These are derivational evidence, not attestations of the headword.
- **Glossed synonyms** (`*Pastis* signifiait Mur` — `Pastis` is being glossed, not attesting the headword).
- **Work titles** in citations.
- **The headword itself in isolated italic** (e.g. `notre *Bouffard*`).
- **Latin/Greek embedded in citation quotations** (those are part of the quoted text, not headword attestations).

If you cannot place an italic phrase confidently in one of the three `kind` categories AND distinguish it from the noise list, omit it.

# Worked examples

## Example 1 — etymology + citation + xref

**Body**:
```
Berger, Pastre; dans quelques localités le s ne se prononce pas; du latin *Pastor*, qui s'est conservé dans *Pasteur* et *Pastoureau*. Ce mot signifie aussi Parc, Clôture, Endroit où l'on met les bestiaux à *paitre*; en vieux-français *Pastis* signifiait Mur, Muraille, suivant Roquefort, t. ii, p. 314.
```

**Output**:
```json
{
  "etymologies": [
    {
      "language": "latin",
      "etymon": "Pastor",
      "gloss": null,
      "hedge": null,
      "attribution": null,
      "surface_text": "du latin *Pastor*, qui s'est conservé dans *Pasteur* et *Pastoureau*"
    }
  ],
  "citations": [
    {
      "author": "Roquefort",
      "work": null,
      "editor": null,
      "anthology": null,
      "locator": "t. ii, p. 314",
      "surface_text": "suivant Roquefort, t. ii, p. 314"
    }
  ],
  "cross_references": [],
  "attestations": []
}
```

Note: Roquefort is mentioned with a locator (`t. ii, p. 314`) but no work title is given inline. Per the rule on bare-scholar-with-locator, this still extracts as a citation with `work: null` — the locator carries enough structural signal. (Du Méril's reader would know Roquefort = his *Glossaire*; we do not infer.)

The line `*Pastis* signifiait Mur, Muraille` is **not** an etymology — it's headword-meaning shape (`ce mot signifie aussi`-style construction; here `*Pastis*` is being glossed as a synonym, not cited as an etymon). It's also not an attestation: `*Pastis*` is being defined, not attested in usage.

## Example 2 — hedged + attributed etymology, multiple candidates

**Body**:
```
Grand mangeur; plutôt de *Buffare*, Se gonfler de mangeaille, que du grec <gr>Βουφαγος</gr>, qui mange un bœuf, auquel le rattache Borel.
```

**Output**:
```json
{
  "etymologies": [
    {
      "language": null,
      "etymon": "Buffare",
      "gloss": "Se gonfler de mangeaille",
      "hedge": "plutôt",
      "attribution": null,
      "surface_text": "plutôt de *Buffare*, Se gonfler de mangeaille"
    },
    {
      "language": "greek",
      "etymon": "Βουφαγος",
      "gloss": "qui mange un bœuf",
      "hedge": null,
      "attribution": "Borel",
      "surface_text": "du grec <gr>Βουφαγος</gr>, qui mange un bœuf, auquel le rattache Borel"
    }
  ],
  "citations": [],
  "cross_references": [],
  "attestations": []
}
```

Note: the first etymon has `language: null` because it matches the **chained-alternative shape** — Du Méril writes `plutôt de *Buffare*, ... que du grec`, weighing two candidate sources. The first candidate lacks an explicit language preposition, but the hedge (`plutôt`) and the parallel construction with the second candidate make the etymological intent unambiguous. Capture the etymon, mark language null, set the hedge.

This is the only path by which a `language: null` etymon enters the output. A bare italic noun in body prose without etymological framing is not extractable.

## Example 3 — anthology-wrapped citation with bold incipit

**Body**:
```
:
Les chouans sont sous vos murs,
déjà ces Vespasiens
Devorent de leurs yeux vos substances, vos biens.
**Lalleman**, *La Campénade*, ch. I, p. 9.
[...]
:
Vaspaciens, c'or fuissies vos or vis
[...several verse lines...]
**La volenteis dont mes cuers est ravis**, dans Wackernagel, *Altfranzoesische Lieder*, p. 65.

On dit aussi *Vaspasien*.
```

**Output**:
```json
{
  "etymologies": [],
  "citations": [
    {
      "author": "Lalleman",
      "work": "La Campénade",
      "editor": null,
      "anthology": null,
      "locator": "ch. I, p. 9",
      "surface_text": "**Lalleman**, *La Campénade*, ch. I, p. 9."
    },
    {
      "author": null,
      "work": "Altfranzoesische Lieder",
      "editor": "Wackernagel",
      "anthology": null,
      "locator": "p. 65",
      "surface_text": "dans Wackernagel, *Altfranzoesische Lieder*, p. 65."
    }
  ],
  "cross_references": [],
  "attestations": [
    {
      "form": "Vaspasien",
      "kind": "variant",
      "surface_text": "On dit aussi *Vaspasien*."
    }
  ]
}
```

Note: the bold `**La volenteis...**` is a verse incipit, not a work title. It does not appear anywhere in the citation output. The trailing `On dit aussi *Vaspasien*` is an attested spelling variant of the headword, captured as an attestation with `kind: variant`.

## Example 4 — original work + anthology + editor

**Body**:
```
:
Denys s'y jeue a bondecul.
*Martyr de Saint-Denis*, dans Jubinal, *Mystères inédits*, p. 128, v. 10.
```

**Output**:
```json
{
  "etymologies": [],
  "citations": [
    {
      "author": null,
      "work": "Martyr de Saint-Denis",
      "editor": "Jubinal",
      "anthology": "Mystères inédits",
      "locator": "p. 128, v. 10",
      "surface_text": "*Martyr de Saint-Denis*, dans Jubinal, *Mystères inédits*, p. 128, v. 10."
    }
  ],
  "cross_references": [],
  "attestations": [
    {
      "form": "Se mettre à bondecul",
      "kind": "locution",
      "surface_text": "*Se mettre à bondecul* signifie *Lever le derrière en l'arrondissant comme une bonde*"
    }
  ]
}
```

Note: the entry-leading italic `*Se mettre à bondecul*` is the locution being defined — captured as `kind: locution`. The italic gloss `*Lever le derrière...*` that immediately follows is the definition, not an attestation, and does not extract.

## Example 5 — cross-references

**Body**:
```
[...] le pronom et signifie, comme en rouchi, Se donner beaucoup de peine; voyez **bavolet**. Voy. le mot suivant.
```

**Output**:
```json
{
  "etymologies": [],
  "citations": [],
  "cross_references": [
    {
      "surface_form": "bavolet",
      "normalized": "bavolet",
      "shape": "voy_bold"
    },
    {
      "surface_form": "le mot suivant",
      "normalized": "le mot suivant",
      "shape": "voy_variant"
    }
  ],
  "attestations": []
}
```

## Example 6 — attestations (place name + variant)

**Body**:
```
Magasin pour les marchandises : il y avait autrefois à Caen une rue appelée la *Rue des Seulles*. En vieux-français *Seulle* signifiait Cave, et Fond de navire qui servait de magasin : nous avons encore *Cellier* dont l'origine peut être la même. On dit aussi *Suelle*.
```

**Output**:
```json
{
  "etymologies": [],
  "citations": [],
  "cross_references": [],
  "attestations": [
    {
      "form": "Rue des Seulles",
      "kind": "phrase",
      "surface_text": "il y avait autrefois à Caen une rue appelée la *Rue des Seulles*"
    },
    {
      "form": "Suelle",
      "kind": "variant",
      "surface_text": "On dit aussi *Suelle*."
    }
  ]
}
```

Note what does NOT appear in attestations:
- `*Seulle*` (in `*Seulle* signifiait Cave`) — being glossed, not attested.
- `*Cellier*` — derivationally related French word Du Méril mentions in passing, not an attestation of the headword.

## Example 7 — etymology with attribution that also extracts as citation

**Body**:
```
Du latin *Pastor*, suivant Roquefort, t. ii, p. 314; à comparer avec l'italien *Pastore*.
```

**Output**:
```json
{
  "etymologies": [
    {
      "language": "latin",
      "etymon": "Pastor",
      "gloss": null,
      "hedge": null,
      "attribution": "Roquefort",
      "surface_text": "Du latin *Pastor*, suivant Roquefort, t. ii, p. 314"
    }
  ],
  "citations": [
    {
      "author": "Roquefort",
      "work": null,
      "editor": null,
      "anthology": null,
      "locator": "t. ii, p. 314",
      "surface_text": "suivant Roquefort, t. ii, p. 314"
    }
  ],
  "cross_references": [],
  "attestations": []
}
```

Note: Roquefort appears in both outputs — once as `etymology.attribution` (he's the scholar Du Méril credits for the Latin etymology), once as `citation.author` (he's cited with a locator). The dual extraction is intentional. The trailing `l'italien *Pastore*` is a cognate listing, not an etymon, and does not extract.

# Final reminders

- Emit valid JSON only. No prose preamble or commentary.
- Empty arrays for passes with no extractions, never omit the key.
- Strict certain-or-omit: `null` field beats wrong field; omit candidate beats wrong candidate.
- Preserve order of citations and attestations as they appear in the body (downstream pairs them with quotations by textual position).
- Strip italic and bold markers from extracted values (`etymon`, `work`, `author`, `surface_form`, `form`). Preserve them in `surface_text`.

Now extract from this entry body:

{ENTRY_BODY}
