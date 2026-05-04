
abstract type EntryKind end
struct Standard <: EntryKind end
struct Locution <: EntryKind end
struct Unclassified <: EntryKind end

struct Alias
	raw::String
	normalized::String
end

mutable struct Entry
	headword_raw::String
	headword_normalized::String
	aliases::Vector{Alias}
	pos_raw::Union{String, Nothing}
	pos_normalized::Union{String, Nothing}
	region_raw::Union{String, Nothing}
	region_normalized::Union{String, Nothing}
	body::String
	page::Int
	source_line::Int
	kind::EntryKind
	flags::Vector{Symbol}
end

struct Etymology end
struct Citation end
struct Quotation end
struct CrossReference end
struct IntroEntry end
struct Footnote end
