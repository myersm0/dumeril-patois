
using TOML

const allowed_gram_fields = (
	:pos, :gender, :number, :valency, :mood, :tense, :subclass, :register, :function_,
)

struct ParsedClosedSets
	parts_of_speech::Dict{String, Vector{PosTag}}
	locutions::Set{String}
	citation_locators::Set{String}
	regions::Dict{String, Vector{String}}
end

field_symbol(name::AbstractString) = name == "function" ? :function_ : Symbol(name)

function expand_sugar_dict(table::AbstractDict)
	scalar = Dict{Symbol, String}()
	array_field = nothing
	array_values = String[]
	for (key, value) in table
		field = field_symbol(key)
		field in allowed_gram_fields || error("Unknown gram field: $(key)")
		if value isa AbstractVector
			array_field === nothing || error("Multiple array fields in sugar form: $(table)")
			array_field = field
			array_values = String.(value)
		else
			scalar[field] = String(value)
		end
	end
	if array_field === nothing
		[PosTag(; scalar...)]
	else
		[PosTag(; scalar..., array_field => v) for v in array_values]
	end
end

function pos_tags_from_value(value)
	if value isa AbstractDict
		expand_sugar_dict(value)
	elseif value isa AbstractVector
		[tag for table in value for tag in expand_sugar_dict(table)]
	else
		error("Unexpected pos value type: $(typeof(value))")
	end
end

function load_closed_sets(path)
	data = TOML.parsefile(path)
	parts_of_speech = Dict{String, Vector{PosTag}}()
	for (surface, value) in get(data, "parts_of_speech", Dict{String, Any}())
		parts_of_speech[surface] = pos_tags_from_value(value)
	end
	locutions = Set{String}(keys(get(data, "locutions", Dict{String, Any}())))
	citation_locators = Set{String}(keys(get(data, "citation_locators", Dict{String, Any}())))
	regions = Dict{String, Vector{String}}()
	for (surface, value) in get(data, "regions", Dict{String, Any}())
		regions[surface] = value isa AbstractVector ? Vector{String}(value) : String[String(value)]
	end
	ParsedClosedSets(parts_of_speech, locutions, citation_locators, regions)
end
