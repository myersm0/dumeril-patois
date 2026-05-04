using DumerilPatois

function classify_line(line)
	stripped = strip(replace(line, "**" => ""))
	isempty(stripped) && return :blank
	occursin(r"^—\s*[IVXLCDM]+\s*—$", stripped) && return :catchword
	parts = split(stripped)
	length(parts) > 4 && return :content
	all_recognized = all(parts) do part
		occursin(r"^\d{1,3}$", part) || occursin(r"^\p{Lu}{2,5}$", part)
	end
	all_recognized || return :content
	any(part -> occursin(r"^\p{Lu}{2,5}$", part), parts) && return :catchword
	length(parts) == 1 && occursin(r"^\d{1,2}$", parts[1]) && return :signature
	:content
end

const sentence_terminal = r"[.!?]\s*$"

function join_at_strip(prev::AbstractString, next::AbstractString)
	prev_trimmed = rstrip(prev)
	next_trimmed = lstrip(next)
	if endswith(prev_trimmed, "-") && occursin(r"^\p{Ll}", next_trimmed)
		word_match = match(r"^(\p{L}+)(.*)$", next_trimmed)
		if word_match !== nothing
			word, rest = word_match.captures
			return chop(prev_trimmed) * word * rest
		end
	end
	if !occursin(sentence_terminal, prev_trimmed)
		return prev_trimmed * " " * next_trimmed
	end
	prev_trimmed * "\n\n" * next_trimmed
end

function sentence_case_smallcaps(text)
	replace(text, r"\*\*([^*]+)\*\*" => function (matched)
		inner = chop(matched, head = 2, tail = 2)
		if occursin(r"\p{Lu}", inner) && !occursin(r"\p{Ll}", inner)
			"**" * uppercasefirst(lowercase(inner)) * "**"
		else
			matched
		end
	end)
end

function clean_page(text)
	lines = split(text, '\n')
	signatures = String[]
	output = String[]
	pending_join = false

	for line in lines
		category = classify_line(line)
		if category == :catchword
			any(!isempty(strip(existing)) for existing in output) && (pending_join = true)
		elseif category == :signature
			push!(signatures, strip(line))
			any(!isempty(strip(existing)) for existing in output) && (pending_join = true)
		elseif category == :blank
			pending_join || push!(output, "")
		else
			if pending_join
				last_content = findlast(existing -> !isempty(strip(existing)), output)
				if last_content !== nothing
					joined = join_at_strip(output[last_content], line)
					output = output[1:last_content - 1]
					append!(output, split(joined, '\n'))
				else
					push!(output, line)
				end
				pending_join = false
			else
				push!(output, line)
			end
		end
	end

	while !isempty(output) && isempty(strip(output[1]))
		popfirst!(output)
	end
	while !isempty(output) && isempty(strip(output[end]))
		pop!(output)
	end

	sentence_case_smallcaps(join(output, '\n')), signatures
end

function build_section(pages)
	parts = String[]
	for (index, (page_number, text)) in enumerate(pages)
		marker = "[page $(lpad(page_number, 3, '0'))]"
		if index == 1
			push!(parts, marker)
			push!(parts, text)
			continue
		end

		previous_lines = split(parts[end], '\n')
		previous_index = findlast(line -> !isempty(strip(line)), previous_lines)
		current_lines = split(text, '\n')
		current_index = findfirst(line -> !isempty(strip(line)), current_lines)

		hyphenated = false
		if previous_index !== nothing && current_index !== nothing
			previous_line = rstrip(previous_lines[previous_index])
			current_line = lstrip(current_lines[current_index])
			if endswith(previous_line, "-") && occursin(r"^\p{Ll}", current_line)
				word_match = match(r"^(\p{L}+)(.*)$", current_line)
				if word_match !== nothing
					word, rest = word_match.captures
					previous_lines[previous_index] = chop(previous_line) * word
					current_lines[current_index] = rest
					parts[end] = join(previous_lines, '\n')
					push!(parts, marker)
					push!(parts, join(current_lines, '\n'))
					hyphenated = true
				end
			end
		end
		if !hyphenated
			push!(parts, marker)
			push!(parts, text)
		end
	end
	join(parts, "\n\n")
end

function parse_page_number(filename)
	page_match = match(r"page_0*(\d+)\.md", filename)
	page_match === nothing ? nothing : parse(Int, page_match.captures[1])
end

function concatenate_pages(input_dir, intro_path, dictionary_path; dictionary_start = 109)
	files = sort(filter(file -> startswith(file, "page_") && endswith(file, ".md"), readdir(input_dir)))
	page_numbers = filter(!isnothing, parse_page_number.(files))

	expected = collect(first(page_numbers):last(page_numbers))
	page_numbers == expected || error("Missing pages: $(setdiff(expected, page_numbers))")

	signatures_log = Pair{Int, Vector{String}}[]
	intro_pages = Tuple{Int, String}[]
	dictionary_pages = Tuple{Int, String}[]

	for (filename, page_number) in zip(files, page_numbers)
		text = read(joinpath(input_dir, filename), String)
		cleaned, signatures = clean_page(text)
		isempty(signatures) || push!(signatures_log, page_number => signatures)
		if page_number < dictionary_start
			push!(intro_pages, (page_number, cleaned))
		else
			push!(dictionary_pages, (page_number, cleaned))
		end
	end

	mkpath(dirname(intro_path))
	mkpath(dirname(dictionary_path))
	write(intro_path, build_section(intro_pages))
	write(dictionary_path, build_section(dictionary_pages))

	signatures_log
end

log = concatenate_pages("data/raw/ocr/opus", "build/intro.md", "build/dictionary.md")
foreach(entry -> println(stderr, "page $(entry.first): ", join(entry.second, ", ")), log)

