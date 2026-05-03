using DumerilPatois

jp2_path = ARGS[1]
model = length(ARGS) >= 2 ? ARGS[2] : "claude-opus-4-7"
print(ocr_page_anthropic(jp2_path; model))
