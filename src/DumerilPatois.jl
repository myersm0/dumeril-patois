module DumerilPatois

using FileIO
using Images
using HTTP
using JSON3
using Base64

include("preprocessing.jl")
include("ocr.jl")

export preprocess_page, ocr_page

end
