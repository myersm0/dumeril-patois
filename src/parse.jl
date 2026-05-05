Base.@kwdef struct Pass1Candidate
	headwords::Vector{String}
	after_bold::String
	full_paragraph::String
	page::Int
	source_line::Int
end

const page_marker_pattern = r"^\[page\s+(\d+)\]\s*$"
const noise_section_divider = r"^\p{Lu}\s*$"
const noise_signature = r"^\d{1,3}\s*$"
const noise_dictionary_title = r"^DICTIONNAIRE\s+PATOIS\s+NORMAND\.\s*$"

function is_noise(paragraph::AbstractString)
	occursin(noise_section_divider, paragraph) && return true
	occursin(noise_signature, paragraph) && return true
	occursin(noise_dictionary_title, paragraph) && return true
	false
end

function each_paragraph(text::AbstractString)
	paragraphs = NamedTuple{(:text, :source_line), Tuple{String, Int}}[]
	lines = split(text, '\n')
	paragraph_buffer = String[]
	paragraph_first_line = 0

	for line_index in 1:(length(lines) + 1)
		line_is_blank = line_index > length(lines) || isempty(strip(lines[line_index]))

		if !line_is_blank
			isempty(paragraph_buffer) && (paragraph_first_line = line_index)
			push!(paragraph_buffer, String(lines[line_index]))
			continue
		end

		isempty(paragraph_buffer) && continue
		paragraph = String(strip(join(paragraph_buffer, '\n')))
		empty!(paragraph_buffer)
		isempty(paragraph) && continue

		push!(paragraphs, (text = paragraph, source_line = paragraph_first_line))
	end

	paragraphs
end

function leading_locution_marker(content::AbstractString, locutions::Set{String})
	for marker in sort(collect(locutions), by = length, rev = true)
		startswith(content, marker) && return marker
	end
	nothing
end

const french_preposition_tail = r"^(?:de\s+l'|d'|de\s+la\s+|du\s+|de\s+)"

function strip_french_preposition_tail(text::AbstractString)
	stripped = String(strip(text))
	preposition_match = match(french_preposition_tail, stripped)
	preposition_match === nothing && return stripped
	String(strip(rest_after(stripped, preposition_match)))
end

const region_shape_prefix = r"^(?:arr\.|arrond\.|ar\.|cant\.|Canton|canton|Arr\.|Orne|Manche|Calvados|Eure|Seine-Inférieure|Haute-Normandie)\b"

function looks_like_region(content::AbstractString)
	occursin(region_shape_prefix, String(strip(content)))
end

function pos_token_classification(pos_token::AbstractString, closed_sets::ParsedClosedSets)
	pos_token in closed_sets.citation_locators && return :citation_locator
	haskey(closed_sets.parts_of_speech, pos_token) && return :part_of_speech
	pos_token in closed_sets.locutions && return :locution
	:none
end

function pos_follows(text::AbstractString, closed_sets::ParsedClosedSets)
	pos_match = match(pos_pattern, text)
	pos_match === nothing && return false
	classification = pos_token_classification(String(strip(pos_match.match)), closed_sets)
	classification == :part_of_speech || classification == :locution
end

function classify_candidate(candidate::Pass1Candidate, closed_sets::ParsedClosedSets)
	rest = strip_leading_separator(candidate.after_bold)

	if startswith(rest, "*") && !startswith(rest, "**")
		return nothing
	end

	headword_raw = candidate.headwords[1]
	headword_normalized = normalize_headword(headword_raw)
	aliases = Alias[]
	for extra in candidate.headwords[2:end]
		push!(aliases, Alias(extra, normalize_headword(extra)))
	end

	pos_raw = nothing
	pos_tags = PosTag[]
	region_raw = nothing
	regions = String[]
	headword_qualifier = nothing
	kind = Standard()

	if startswith(rest, "(")
		paren_match = match(region_parens_pattern, rest)
		if paren_match !== nothing
			paren_content = String(strip(paren_match.captures[1]))
			after_paren = strip_leading_separator(rest_after(rest, paren_match))
			locution_marker = leading_locution_marker(paren_content, closed_sets.locutions)

			if haskey(closed_sets.regions, paren_content)
				regions = closed_sets.regions[paren_content]
				region_raw = paren_content
				rest = after_paren
			elseif locution_marker !== nothing
				kind = Locution()
				region_raw = paren_content
				marker_length = ncodeunits(locution_marker)
				tail = marker_length >= ncodeunits(paren_content) ?
					"" : paren_content[nextind(paren_content, marker_length):end]
				residual = strip_french_preposition_tail(tail)
				if haskey(closed_sets.regions, residual)
					regions = closed_sets.regions[residual]
				end
				body = String(strip(after_paren))
				return Entry(
					headword_raw = headword_raw,
					headword_normalized = headword_normalized,
					aliases = aliases,
					pos_raw = pos_raw,
					pos_tags = pos_tags,
					region_raw = region_raw,
					regions = regions,
					headword_qualifier = headword_qualifier,
					body = body,
					page = candidate.page,
					source_line = candidate.source_line,
					kind = kind,
				)
			elseif is_bold_token_paren(paren_content)
				inner = bold_token_inner(paren_content)
				push!(aliases, Alias(inner, normalize_headword(inner)))
				rest = after_paren
			elseif looks_like_region(paren_content)
				region_raw = paren_content
				regions = String[]
				rest = after_paren
			elseif pos_follows(after_paren, closed_sets)
				headword_qualifier = paren_content
				rest = after_paren
			else
				kind = Unclassified()
				headword_qualifier = paren_content
				body = String(strip(after_paren))
				return Entry(
					headword_raw = headword_raw,
					headword_normalized = headword_normalized,
					aliases = aliases,
					pos_raw = pos_raw,
					pos_tags = pos_tags,
					region_raw = region_raw,
					regions = regions,
					headword_qualifier = headword_qualifier,
					body = body,
					page = candidate.page,
					source_line = candidate.source_line,
					kind = kind,
				)
			end
		end
	end

	pos_match = match(pos_pattern, rest)
	if pos_match !== nothing
		pos_token = String(strip(pos_match.match))
		classification = pos_token_classification(pos_token, closed_sets)

		if classification == :citation_locator
			return nothing
		elseif classification == :part_of_speech
			pos_raw = pos_token
			pos_tags = closed_sets.parts_of_speech[pos_token]
			rest = strip_leading_separator(rest_after(rest, pos_match))
		elseif classification == :locution
			pos_raw = pos_token
			kind = Locution()
			rest = strip_leading_separator(rest_after(rest, pos_match))
		end
	end

	if region_raw === nothing && startswith(rest, "(")
		paren_match = match(region_parens_pattern, rest)
		if paren_match !== nothing
			paren_content = String(strip(paren_match.captures[1]))
			after_paren = strip_leading_separator(rest_after(rest, paren_match))
			if haskey(closed_sets.regions, paren_content)
				regions = closed_sets.regions[paren_content]
				region_raw = paren_content
				rest = after_paren
			elseif looks_like_region(paren_content)
				region_raw = paren_content
				regions = String[]
				rest = after_paren
			end
		end
	end

	body = String(strip(rest))
	Entry(
		headword_raw = headword_raw,
		headword_normalized = headword_normalized,
		aliases = aliases,
		pos_raw = pos_raw,
		pos_tags = pos_tags,
		region_raw = region_raw,
		regions = regions,
		headword_qualifier = headword_qualifier,
		body = body,
		page = candidate.page,
		source_line = candidate.source_line,
		kind = kind,
	)
end

function append_to_body!(entry::Entry, body_paragraphs::Vector{String})
	appended_body = String(strip(join(body_paragraphs, "\n\n")))
	isempty(appended_body) && return
	entry.body = isempty(entry.body) ? appended_body : entry.body * "\n\n" * appended_body
end

function parse_entries(text::AbstractString, closed_sets::ParsedClosedSets)
	entries = Entry[]
	current_entry = nothing
	body_paragraphs = String[]
	current_page = 0
	in_errata = false

	for paragraph_info in each_paragraph(text)
		paragraph = paragraph_info.text
		source_line = paragraph_info.source_line

		page_match = match(page_marker_pattern, paragraph)
		if page_match !== nothing
			current_page = parse(Int, page_match.captures[1])
			continue
		end
		if occursin(erratum_marker, paragraph)
			in_errata = true
			continue
		end
		in_errata && continue
		is_noise(paragraph) && continue

		headwords, after_bold = consume_bold_group(paragraph)

		if isempty(headwords)
			current_entry !== nothing && push!(body_paragraphs, paragraph)
			continue
		end

		candidate = Pass1Candidate(
			headwords = headwords,
			after_bold = String(after_bold),
			full_paragraph = paragraph,
			page = current_page,
			source_line = source_line,
		)
		result = classify_candidate(candidate, closed_sets)

		if result === nothing
			current_entry !== nothing && push!(body_paragraphs, paragraph)
			continue
		end

		if current_entry !== nothing
			append_to_body!(current_entry, body_paragraphs)
			push!(entries, current_entry)
		end
		current_entry = result
		body_paragraphs = String[]
	end

	if current_entry !== nothing
		append_to_body!(current_entry, body_paragraphs)
		push!(entries, current_entry)
	end

	entries
end
