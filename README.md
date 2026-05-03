# dumeril-patois
Structured edition of Édélestand and Alfred Du Méril, *Dictionnaire du patois normand* (Caen: B. Mancel, 1849).

## Pipeline
Three phases:

1. **Preprocessing.** JP2 page scans are converted to cropped, upright PNGs. Per-parity rotation (even and odd pages were scanned in opposite orientations) and a hard-coded crop remove the facing-page sliver visible at each scan's edge (otherwise the LLM would try to parse that sliver of text no matter what).
2. **OCR.** Cropped PNGs are OCR'd to markdown transcription via local Ollama running Qwen 2.5-VL 32B. Verbatim transcription only; typography reconstruction is deferred to cleanup.
3. **Cleanup + parsing.** Markdown is converted to SQLite (_not yet implemented_). Detect entries, infer italics from closed-set triggers, emit structured tables.

## Build

	scripts/acquire.sh
	ollama pull qwen2.5vl:32b
	julia --project=. scripts/ocr_all_pages.jl
	julia --project=. scripts/build.jl

## License
CC-BY-SA 4.0. See [LICENSE](LICENSE).
