using HTTP, JSON3, Base64

const anthropic_url = "https://api.anthropic.com/v1/messages"
const default_anthropic_model = "claude-opus-4-7"
const ocr_prompt_anthropic = ocr_prompt * """

TYPOGRAPHY MARKERS — examine the letterforms carefully:
- SMALL CAPS → wrap in **WORD**. Headwords at the start of each dictionary entry are printed in small caps and must be marked.
- ITALICS → wrap in *...*. Look for sloped, cursive letterforms that differ from upright roman type. Italics commonly appear on etymological forms, cited foreign words, and work titles. Mark every italic run, including single italicized words inside otherwise-roman text. Example: in "du latin *adversus*", the word "adversus" is italic and must be marked.
- GREEK → wrap in <gr>...</gr>
"""

function ocr_page_anthropic(jp2_path::String; model::String = default_anthropic_model)
	png_path = preprocess_page(jp2_path)
	resized_path = tempname() * ".png"
	run(pipeline(`sips -Z 2000 $png_path --out $resized_path`, stdout = devnull))
	image_base64 = base64encode(read(resized_path))

	body = JSON3.write((
		model = model,
		max_tokens = 8192,
		messages = [(
			role = "user",
			content = [
				(type = "image", source = (type = "base64", media_type = "image/png", data = image_base64)),
				(type = "text", text = ocr_prompt_anthropic),
			],
		)],
	))

	response = HTTP.post(
		anthropic_url;
		headers = [
			"x-api-key" => ENV["ANTHROPIC_API_KEY"],
			"anthropic-version" => "2023-06-01",
			"content-type" => "application/json",
		],
		body,
		readtimeout = 300,
	)

	result = JSON3.read(response.body)
	rm(png_path; force = true)

	usage = result.usage
	println(stderr, "tokens: input=$(usage.input_tokens) output=$(usage.output_tokens) model=$model")

	return result.content[1].text
end
