
function discover_in_paragraph(paragraph)
	first_line = split(paragraph, '\n', limit = 2)[1]
	headwords, after_bold = consume_bold_group(String(first_line))
	isempty(headwords) && return nothing
	rest = after_bold
	pos_form = nothing
	region_form = nothing
	for _ in 1:3
		separator_match = match(leading_separator, rest)
		separator_match !== nothing && (rest = rest_after(rest, separator_match))
		if pos_form === nothing
			pos_match = match(pos_pattern, rest)
			if pos_match !== nothing
				pos_form = String(strip(pos_match.match))
				rest = rest_after(rest, pos_match)
				continue
			end
		end
		if region_form === nothing
			region_match = match(region_parens_pattern, rest)
			if region_match !== nothing
				region_form = String(strip(region_match.captures[1]))
				rest = rest_after(rest, region_match)
				continue
			end
		end
		break
	end
	(headwords = headwords, pos = pos_form, region = region_form)
end

function discover_closed_sets(entries_path)
	text = read(entries_path, String)
	paragraphs = split(text, r"\n\s*\n")
	pos_counts = Dict{String, Int}()
	region_counts = Dict{String, Int}()
	for paragraph in paragraphs
		stripped = strip(paragraph)
		isempty(stripped) && continue
		occursin(erratum_marker, stripped) && break
		result = discover_in_paragraph(String(stripped))
		result === nothing && continue
		if result.pos !== nothing
			pos_counts[result.pos] = get(pos_counts, result.pos, 0) + 1
		end
		if result.region !== nothing
			region_counts[result.region] = get(region_counts, result.region, 0) + 1
		end
	end
	pos_counts, region_counts
end

toml_quote(s) = "\"" * replace(s, "\\" => "\\\\", "\"" => "\\\"") * "\""

function write_discovered_closed_sets(path, pos_counts, region_counts)
	open(path, "w") do io
		println(io, "# Discovered candidate closed sets from build/entries.md.")
		println(io, "# Inline comments show occurrence counts (sorted descending).")
		println(io, "# Review and merge into config/closed_sets.toml.")
		println(io)
		println(io, "[parts_of_speech]")
		for (form, count) in sort(collect(pos_counts); by = last, rev = true)
			println(io, "$(toml_quote(form)) = \"\"  # $(count)")
		end
		println(io)
		println(io, "[regions]")
		for (form, count) in sort(collect(region_counts); by = last, rev = true)
			println(io, "$(toml_quote(form)) = \"\"  # $(count)")
		end
	end
end

const etymology_candidate_pattern = r"(?<prep>de l'|du |de la |de |en )(?<lang>[\p{L}\-]+)\s+(?:\*[^*]+\*|<gr>[^<]+</gr>)"

function strip_page_markers(text::AbstractString)
	replace(text, r"\s*\[page\s+\d+\]\s*" => " ")
end

function discover_etymology_languages(entries_jsonl_path)
	counts = Dict{String, Int}()
	for line in eachline(entries_jsonl_path)
		entry = JSON3.read(line)
		scan_text = strip_page_markers(entry.body)
		for hit in eachmatch(etymology_candidate_pattern, scan_text)
			surface = hit["prep"] * hit["lang"]
			counts[surface] = get(counts, surface, 0) + 1
		end
	end
	counts
end

function write_discovered_etymology_languages(path, counts)
	open(path, "w") do io
		println(io, "# Discovered etymology language surface forms from build/entries.jsonl.")
		println(io, "# Inline comments show occurrence counts (sorted descending).")
		println(io, "# Review and merge into [etymology_languages] in config/closed_sets.toml.")
		println(io)
		println(io, "[etymology_languages]")
		for (form, count) in sort(collect(counts); by = last, rev = true)
			println(io, "$(toml_quote(form)) = \"\"  # $(count)")
		end
	end
end
