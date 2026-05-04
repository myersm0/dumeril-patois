
using Unicode

const pos_pattern = r"^\p{Ll}+\.(?:\s+\p{Ll}+\.)*(?:\s+(?:et|ou)\s+\p{Ll}+\.(?:\s+\p{Ll}+\.)*)*"
const region_parens_pattern = r"^\(\s*([^)]+?)\s*\)"
const bold_token = r"^\*\*([^*]+)\*\*"
const headword_separator = r"^\s*(?:,\s+|et\s+|ou\s+)(?=\*\*)"
const leading_separator = r"^[\s,]+"
const erratum_marker = r"^ERRATA\.?\s*$"

function rest_after(text, regex_match)
	stop = ncodeunits(regex_match.match)
	stop >= ncodeunits(text) && return ""
	text[nextind(text, stop):end]
end

function consume_bold_group(text)
	headwords = String[]
	rest = text
	first_bold = match(bold_token, rest)
	first_bold === nothing && return headwords, text
	push!(headwords, first_bold.captures[1])
	rest = rest_after(rest, first_bold)
	while true
		separator = match(headword_separator, rest)
		separator === nothing && break
		after_separator = rest_after(rest, separator)
		bold = match(bold_token, after_separator)
		bold === nothing && break
		push!(headwords, bold.captures[1])
		rest = rest_after(after_separator, bold)
	end
	headwords, rest
end

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
