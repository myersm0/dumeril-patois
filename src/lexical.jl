
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
