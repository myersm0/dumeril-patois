
abstract type EntryKind end
struct Standard <: EntryKind end
struct Locution <: EntryKind end
struct Multiword <: EntryKind end
struct Unclassified <: EntryKind end
 
mutable struct Entry
	headword_raw::String
	headword_normalized::String
	pos_raw::Union{String,Nothing}
	region::Union{String,Nothing}
	body::String
	page::Int
	kind::EntryKind
	flags::Vector{Symbol}
end
 
# placeholders, flesh out as workstreams F+ define their schemas
struct Etymology end
struct Citation end
struct Quotation end
struct CrossReference end
struct IntroEntry end
struct Footnote end

