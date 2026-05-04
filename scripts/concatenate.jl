using DumerilPatois

input_dir = length(ARGS) >= 1 ? ARGS[1] : "data/raw/ocr/opus"
intro_path = length(ARGS) >= 2 ? ARGS[2] : "build/intro.md"
entries_path = length(ARGS) >= 3 ? ARGS[3] : "build/entries.md"

mkpath(dirname(intro_path))
mkpath(dirname(entries_path))

signatures = concatenate_pages(input_dir, intro_path, entries_path)

for (page, marks) in signatures
	println("page $page: stripped signature marks $marks")
end

