module DumerilPatois

using FileIO
using Images
using HTTP
using JSON3
using Base64

include("preprocessing.jl")
include("ocr.jl")
include("concatenate.jl")
include("model.jl")
include("lexical.jl")
include("parse.jl")
include("discover.jl")

export preprocess_page, ocr_page, concatenate_pages
export discover_closed_sets, write_discovered_closed_sets
export parse_entries, load_closed_sets, entry_to_dict
export Entry, Alias, PosTag, EntryKind, Standard, Locution, Unclassified

end
