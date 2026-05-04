
const postag_serializable_fields = (
	(:gender, "gender"),
	(:number, "number"),
	(:valency, "valency"),
	(:mood, "mood"),
	(:tense, "tense"),
	(:subclass, "subclass"),
	(:register, "register"),
	(:function_, "function"),
)

function postag_to_dict(tag::PosTag)
	result = Dict{String, Any}("pos" => tag.pos)
	for (field, json_key) in postag_serializable_fields
		value = getfield(tag, field)
		value !== nothing && (result[json_key] = value)
	end
	result
end

kind_string(::Standard) = "standard"
kind_string(::Locution) = "locution"
kind_string(::Unclassified) = "unclassified"

function entry_to_dict(entry::Entry)
	Dict{String, Any}(
		"headword_raw" => entry.headword_raw,
		"headword_normalized" => entry.headword_normalized,
		"aliases" => [Dict{String, Any}("raw" => alias.raw, "normalized" => alias.normalized)
			for alias in entry.aliases],
		"pos_raw" => entry.pos_raw,
		"pos_tags" => [postag_to_dict(tag) for tag in entry.pos_tags],
		"region_raw" => entry.region_raw,
		"regions" => entry.regions,
		"headword_qualifier" => entry.headword_qualifier,
		"body" => entry.body,
		"page" => entry.page,
		"source_line" => entry.source_line,
		"kind" => kind_string(entry.kind),
		"flags" => [String(flag) for flag in entry.flags],
	)
end
