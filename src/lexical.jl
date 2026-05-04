
using Unicode

const pos_pattern = r"^\p{Ll}+\.(?:\s+\p{Ll}+\.)*(?:\s+(?:et|ou)\s+\p{Ll}+\.(?:\s+\p{Ll}+\.)*)*"
const region_parens_pattern = r"^\(\s*([^)]+?)\s*\)"
const bold_token = r"^\*\*([^*]+)\*\*"
const standalone_bold_pattern = r"^\*\*([^*]+)\*\*$"
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

function normalize_headword(text::AbstractString)
	stripped = Unicode.normalize(text, stripmark = true)
	String(strip(lowercase(stripped)))
end

function strip_leading_separator(text::AbstractString)
	separator_match = match(leading_separator, text)
	separator_match === nothing ? String(text) : String(rest_after(text, separator_match))
end

function is_bold_token_paren(content::AbstractString)
	occursin(standalone_bold_pattern, String(strip(content)))
end

function bold_token_inner(content::AbstractString)
	bold_match = match(standalone_bold_pattern, String(strip(content)))
	bold_match === nothing ? "" : String(bold_match.captures[1])
end
