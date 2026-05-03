module DumerilPatois

using FileIO
using Images
using HTTP
using JSON3
using Base64

include("preprocessing.jl")
include("ocr.jl")
#include("ocr_cleanup.jl")
#include("entry_parser.jl")
#include("intro_parser.jl")

export preprocess_page, ocr_page

end
