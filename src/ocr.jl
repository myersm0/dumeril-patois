using HTTP, JSON3, Base64

const ollama_url = "http://localhost:11434/api/generate"
const ollama_model = "qwen2.5vl:32b"

const ocr_prompt = """
Transcribe this page verbatim.

REFLOW: Do not preserve line breaks that exist only because the original text wrapped at page width. Join wrapped lines into continuous text. Insert line breaks ONLY at semantic boundaries: paragraph breaks, new dictionary entries, verse lines, footnote starts.

PRESERVE EVERYTHING ELSE EXACTLY: spellings, archaic forms, diacritics, mixed scripts (Greek, Old Norse þ ð æ, Latin). Do not normalize, modernize, or correct.

ILLEGIBLE: single character → ⟨?⟩; whole word → ⟨???⟩. Do not guess.

Output only the transcription. No commentary, no preamble.
"""

function ocr_page(jp2_path::String)
	png_path = preprocess_page(jp2_path)
	image_base64 = base64encode(read(png_path))
	body = JSON3.write((
		model = ollama_model,
		prompt = ocr_prompt,
		images = [image_base64],
		stream = false,
		options = (; temperature = 0, num_ctx = 8192),
	))
	response = HTTP.post(ollama_url; body, readtimeout = 1200)
	rm(png_path; force = true)
	return JSON3.read(response.body).response
end
