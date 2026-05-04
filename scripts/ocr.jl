using DumerilPatois

const jp2_dir = "data/raw/jp2"
const output_dir = "data/raw/ocr/opus"
const start_page = 1
const model = "claude-opus-4-7"

mkpath(output_dir)

jp2_files = sort(filter(f -> endswith(f, ".jp2"), readdir(jp2_dir; join = true)))
filter!(jp2_files) do path
	page_number = parse(Int, match(r"_(\d+)\.jp2$", path).captures[1])
	page_number >= start_page
end
total = length(jp2_files)

for (i, jp2_path) in enumerate(jp2_files)
	page_number = parse(Int, match(r"_(\d+)\.jp2$", jp2_path).captures[1])
	output_path = joinpath(output_dir, "page_$(lpad(page_number, 4, '0')).md")

	if isfile(output_path)
		println(stderr, "[$i/$total] skip $page_number")
		continue
	end

	start = time()
	try
		text = ocr_page(jp2_path; model)
		write(output_path, text)
		elapsed = round(time() - start; digits = 1)
		println(stderr, "[$i/$total] ok $page_number ($(elapsed)s)")
	catch e
		elapsed = round(time() - start; digits = 1)
		println(stderr, "[$i/$total] FAIL $page_number ($(elapsed)s): $e")
	end
end
