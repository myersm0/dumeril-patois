
abstract type EntryKind end
struct Standard <: EntryKind end
struct Locution <: EntryKind end
struct Unclassified <: EntryKind end

struct Alias
	raw::String
	normalized::String
end

Base.@kwdef struct PosTag
	pos::String
	gender::Union{String, Nothing} = nothing
	number::Union{String, Nothing} = nothing
	valency::Union{String, Nothing} = nothing
	mood::Union{String, Nothing} = nothing
	tense::Union{String, Nothing} = nothing
	subclass::Union{String, Nothing} = nothing
	register::Union{String, Nothing} = nothing
	function_::Union{String, Nothing} = nothing
end

Base.@kwdef mutable struct Entry
	headword_raw::String
	headword_normalized::String
	aliases::Vector{Alias} = Alias[]
	pos_raw::Union{String, Nothing} = nothing
	pos_tags::Vector{PosTag} = PosTag[]
	region_raw::Union{String, Nothing} = nothing
	regions::Vector{String} = String[]
	headword_qualifier::Union{String, Nothing} = nothing
	body::String = ""
	page::Int
	source_line::Int
	kind::EntryKind = Standard()
	flags::Vector{Symbol} = Symbol[]
end

struct Etymology end
struct Citation end
struct Quotation end
struct CrossReference end
struct IntroEntry end
struct Footnote end
