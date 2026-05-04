
abstract type EntryKind end
struct Standard <: EntryKind end
struct Locution <: EntryKind end
struct Unclassified <: EntryKind end

struct Alias
	raw::String
	normalized::String
end

struct PosTag
	pos::String
	gender::Union{String, Nothing}
	number::Union{String, Nothing}
	valency::Union{String, Nothing}
	mood::Union{String, Nothing}
	tense::Union{String, Nothing}
	subclass::Union{String, Nothing}
	register::Union{String, Nothing}
	function_::Union{String, Nothing}
end

PosTag(;
	pos,
	gender = nothing,
	number = nothing,
	valency = nothing,
	mood = nothing,
	tense = nothing,
	subclass = nothing,
	register = nothing,
	function_ = nothing,
) = PosTag(
	pos,
	gender,
	number,
	valency,
	mood,
	tense,
	subclass,
	register,
	function_,
)

mutable struct Entry
	headword_raw::String
	headword_normalized::String
	aliases::Vector{Alias}
	pos_raw::Union{String, Nothing}
	pos_tags::Vector{PosTag}
	region_raw::Union{String, Nothing}
	regions::Vector{String}
	headword_qualifier::Union{String, Nothing}
	body::String
	page::Int
	source_line::Int
	kind::EntryKind
	# extension point; no flag for state derivable from other fields
	flags::Vector{Symbol}
end

Entry(;
	headword_raw,
	headword_normalized,
	aliases = Alias[],
	pos_raw = nothing,
	pos_tags = PosTag[],
	region_raw = nothing,
	regions = String[],
	headword_qualifier = nothing,
	body = "",
	page,
	source_line,
	kind = Standard(),
	flags = Symbol[],
) = Entry(
	headword_raw,
	headword_normalized,
	aliases,
	pos_raw,
	pos_tags,
	region_raw,
	regions,
	headword_qualifier,
	body,
	page,
	source_line,
	kind,
	flags,
)

struct Etymology end
struct Citation end
struct Quotation end
struct CrossReference end
struct IntroEntry end
struct Footnote end
