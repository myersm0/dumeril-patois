using ArgParse
using HTTP
using JSON3
using Random
using TOML
using Unicode

const api_url = "https://api.anthropic.com/v1/messages"
const default_model = "claude-opus-4-7"
const default_max_tokens = 4000

const price_input = 5.00
const price_output = 25.00
const price_cache_write = 6.25
const price_cache_read = 0.50

function build_settings()
	settings = ArgParseSettings(
		description = "Run an LLM pass over Du Méril entries with optional structured-output validation.",
	)
	@add_arg_table! settings begin
		"--prompt"
			help = "path to prompt template file (must contain marker line)"
			required = true
		"--entries"
			help = "path to input JSONL of entries"
			default = "build/entries.jsonl"
		"--output"
			help = "path to output JSONL (default: build/extract_<prompt_stem>.jsonl)"
		"--validator"
			help = "validator name: extraction, none"
			default = "extraction"
		"--closed-sets"
			help = "path to closed_sets.toml"
			default = "config/closed_sets.toml"
		"--prompt-marker"
			help = "marker line that delimits the prompt template body"
			default = "Now extract from this entry body:"
		"--sample"
			help = "total sample size"
			arg_type = Int
			default = 100
		"--seed"
			help = "random seed"
			arg_type = Int
			default = 42
		"--count"
			help = "max entries to process this run"
			arg_type = Int
			default = 20
	end
	settings
end

function default_output_path(prompt_path)
	stem = first(splitext(basename(prompt_path)))
	stem = endswith(stem, "_prompt") ? stem[1:end - length("_prompt")] : stem
	"build/extract_$stem.jsonl"
end

function flatten_values(dict)
	result = String[]
	for value in values(dict)
		if value isa AbstractVector
			append!(result, value)
		else
			push!(result, value)
		end
	end
	Set(result)
end

function load_closed_sets(path)
	config = TOML.parsefile(path)
	languages = flatten_values(get(config, "etymology_languages", Dict{String, Any}()))
	hedges_table = get(config, "etymology_hedges", Dict{String, Any}())
	hedges = Set(get(hedges_table, "allowed", String[]))
	shapes_table = get(config, "cross_reference_shapes", Dict{String, Any}())
	xref_shapes = Set(get(shapes_table, "allowed", String[]))
	(; languages, hedges, xref_shapes)
end

function strip_markup(text)
	text = replace(text, r"<gr>(.*?)</gr>"s => s"\1")
	text = replace(text, r"\*\*(.*?)\*\*"s => s"\1")
	text = replace(text, r"\*(.*?)\*"s => s"\1")
	text
end

function strip_diacritics(text)
	Unicode.normalize(text, stripmark = true)
end

function strip_page_markers(text)
	replace(text, r"\[page \d+\]" => "")
end

function normalize_whitespace(text)
	String(strip(replace(text, r"\s+" => " ")))
end

function contains_robust(haystack, needle)
	occursin(needle, haystack) && return true
	haystack_normalized = Unicode.normalize(haystack, :NFC)
	needle_normalized = Unicode.normalize(needle, :NFC)
	occursin(needle_normalized, haystack_normalized) && return true
	haystack_clean = normalize_whitespace(strip_page_markers(haystack_normalized))
	needle_clean = normalize_whitespace(needle_normalized)
	occursin(needle_clean, haystack_clean)
end

function check_required_keys(object, required)
	[String(key) for key in required if !haskey(object, key)]
end

function validate_etymology(etymology, body, body_stripped, closed_sets)
	required = (:language, :etymon, :gloss, :hedge, :attribution, :surface_text)
	missing_keys = check_required_keys(etymology, required)
	if !isempty(missing_keys)
		return (
			candidate = etymology,
			errors = ["missing keys: " * join(missing_keys, ", ")],
			valid = false,
		)
	end
	errors = String[]
	if etymology.language !== nothing && !(etymology.language in closed_sets.languages)
		push!(errors, "language not in closed set: $(etymology.language)")
	end
	if etymology.hedge !== nothing && !(etymology.hedge in closed_sets.hedges)
		push!(errors, "hedge not in closed set: $(etymology.hedge)")
	end
	if etymology.surface_text === nothing
		push!(errors, "surface_text is null")
	elseif !contains_robust(body, etymology.surface_text)
		push!(errors, "surface_text not found in body")
	end
	if etymology.etymon === nothing
		push!(errors, "etymon is null")
	elseif !contains_robust(body_stripped, strip_markup(etymology.etymon))
		push!(errors, "etymon not found in body: $(etymology.etymon)")
	end
	if etymology.gloss !== nothing && !contains_robust(body_stripped, strip_markup(etymology.gloss))
		push!(errors, "gloss not found in body: $(etymology.gloss)")
	end
	if etymology.attribution !== nothing && !contains_robust(body_stripped, etymology.attribution)
		push!(errors, "attribution not found in body: $(etymology.attribution)")
	end
	(candidate = etymology, errors = errors, valid = isempty(errors))
end

function validate_citation(citation, body, body_stripped, closed_sets)
	required = (:author, :work, :editor, :anthology, :locator, :surface_text)
	missing_keys = check_required_keys(citation, required)
	if !isempty(missing_keys)
		return (
			candidate = citation,
			errors = ["missing keys: " * join(missing_keys, ", ")],
			valid = false,
		)
	end
	errors = String[]
	if citation.surface_text === nothing
		push!(errors, "surface_text is null")
	elseif !contains_robust(body, citation.surface_text)
		push!(errors, "surface_text not found in body")
	end
	if citation.work === nothing
		push!(errors, "work is null (required field)")
	end
	for field in (:author, :work, :editor, :anthology, :locator)
		value = getproperty(citation, field)
		if value !== nothing && !contains_robust(body_stripped, strip_markup(value))
			push!(errors, "$field not found in body: $value")
		end
	end
	(candidate = citation, errors = errors, valid = isempty(errors))
end

function validate_cross_reference(cross_reference, body, body_stripped, closed_sets)
	required = (:surface_form, :normalized, :shape)
	missing_keys = check_required_keys(cross_reference, required)
	if !isempty(missing_keys)
		return (
			candidate = cross_reference,
			errors = ["missing keys: " * join(missing_keys, ", ")],
			valid = false,
		)
	end
	errors = String[]
	if !(cross_reference.shape in closed_sets.xref_shapes)
		push!(errors, "shape not in allowed set: $(cross_reference.shape)")
	end
	if cross_reference.surface_form === nothing
		push!(errors, "surface_form is null")
	elseif !contains_robust(body_stripped, cross_reference.surface_form)
		push!(errors, "surface_form not found in body: $(cross_reference.surface_form)")
	end
	if cross_reference.shape == "voy_bold" &&
	   cross_reference.surface_form !== nothing &&
	   cross_reference.normalized !== nothing
		expected = lowercase(strip_diacritics(cross_reference.surface_form))
		if cross_reference.normalized != expected
			push!(errors, "normalized mismatch: got '$(cross_reference.normalized)', expected '$expected'")
		end
	end
	(candidate = cross_reference, errors = errors, valid = isempty(errors))
end

function validate_extraction(extraction, body, closed_sets)
	schema_errors = String[]
	for key in (:etymologies, :citations, :cross_references)
		if !haskey(extraction, key)
			push!(schema_errors, "missing top-level key: $key")
		elseif getproperty(extraction, key) === nothing
			push!(schema_errors, "$key is null (must be array)")
		elseif !(getproperty(extraction, key) isa AbstractVector)
			push!(schema_errors, "$key is not an array")
		end
	end
	if !isempty(schema_errors)
		return (
			etymologies = [],
			citations = [],
			cross_references = [],
			schema_errors = schema_errors,
		)
	end
	body_stripped = strip_markup(body)
	(
		etymologies = [
			validate_etymology(e, body, body_stripped, closed_sets)
			for e in extraction.etymologies
		],
		citations = [
			validate_citation(c, body, body_stripped, closed_sets)
			for c in extraction.citations
		],
		cross_references = [
			validate_cross_reference(x, body, body_stripped, closed_sets)
			for x in extraction.cross_references
		],
		schema_errors = schema_errors,
	)
end

function validate_none(extraction, body, closed_sets)
	(
		etymologies = [],
		citations = [],
		cross_references = [],
		schema_errors = String[],
	)
end

function get_validator(name)
	name == "extraction" && return validate_extraction
	name == "none" && return validate_none
	error("Unknown validator: $name (known: extraction, none)")
end

function load_prompt(path, marker)
	template = read(path, String)
	parts = split(template, marker)
	length(parts) == 2 || error("prompt template missing marker: $marker")
	String(strip(parts[1]))
end

function call_api(entry_body, system_prompt; api_key = ENV["ANTHROPIC_API_KEY"])
	payload = JSON3.write((
		model = default_model,
		max_tokens = default_max_tokens,
		system = [(
			type = "text",
			text = system_prompt,
			cache_control = (type = "ephemeral",),
		)],
		messages = [(role = "user", content = entry_body)],
	))
	headers = [
		"Content-Type" => "application/json",
		"x-api-key" => api_key,
		"anthropic-version" => "2023-06-01",
	]
	response = HTTP.post(api_url, headers, payload)
	JSON3.read(String(response.body))
end

function parse_response_text(text)
	cleaned = String(strip(text))
	cleaned = replace(cleaned, r"^```(?:json)?\s*" => "")
	cleaned = replace(cleaned, r"\s*```$" => "")
	JSON3.read(cleaned)
end

function compute_cost(usage)
	cache_creation = get(usage, :cache_creation_input_tokens, 0)
	cache_read = get(usage, :cache_read_input_tokens, 0)
	(usage.input_tokens / 1_000_000) * price_input +
	(usage.output_tokens / 1_000_000) * price_output +
	(cache_creation / 1_000_000) * price_cache_write +
	(cache_read / 1_000_000) * price_cache_read
end

function load_entries(path)
	[JSON3.read(line) for line in eachline(path)]
end

function load_done_keys(path)
	isfile(path) || return Set{Tuple{Int, Int}}()
	keys = Set{Tuple{Int, Int}}()
	for line in eachline(path)
		record = JSON3.read(line)
		push!(keys, (record.page, record.source_line))
	end
	keys
end

function load_prior_cost(path)
	isfile(path) || return 0.0
	total = 0.0
	for line in eachline(path)
		record = JSON3.read(line)
		total += compute_cost(record.usage)
	end
	total
end

function build_sample(entries, total, seed)
	indices = randperm(MersenneTwister(seed), length(entries))[1:total]
	[entries[i] for i in indices]
end

function summarize_validation(validation)
	(
		etymologies_valid = count(c -> c.valid, validation.etymologies),
		etymologies_total = length(validation.etymologies),
		citations_valid = count(c -> c.valid, validation.citations),
		citations_total = length(validation.citations),
		cross_references_valid = count(c -> c.valid, validation.cross_references),
		cross_references_total = length(validation.cross_references),
		schema_ok = isempty(validation.schema_errors),
	)
end

function process_entry(entry, system_prompt, validator, closed_sets, output_io)
	response = call_api(entry.body, system_prompt)
	extraction = parse_response_text(response.content[1].text)
	validation = validator(extraction, entry.body, closed_sets)
	usage = (
		input_tokens = response.usage.input_tokens,
		output_tokens = response.usage.output_tokens,
		cache_creation_input_tokens = get(response.usage, :cache_creation_input_tokens, 0),
		cache_read_input_tokens = get(response.usage, :cache_read_input_tokens, 0),
	)
	cost = compute_cost(usage)
	record = (
		page = entry.page,
		source_line = entry.source_line,
		headword_raw = entry.headword_raw,
		pos_raw = entry.pos_raw,
		body = entry.body,
		extraction = extraction,
		validation = validation,
		usage = usage,
		cost = cost,
	)
	JSON3.write(output_io, record)
	println(output_io)
	flush(output_io)
	(record, summarize_validation(validation))
end

function main(args)
	prompt_path = args["prompt"]
	output_path = something(args["output"], default_output_path(prompt_path))
	closed_sets_path = args["closed-sets"]
	entries_path = args["entries"]
	validator_name = args["validator"]
	prompt_marker = args["prompt-marker"]
	total_sample = args["sample"]
	random_seed = args["seed"]
	group_size = args["count"]

	mkpath(dirname(output_path))
	closed_sets = load_closed_sets(closed_sets_path)
	system_prompt = load_prompt(prompt_path, prompt_marker)
	validator = get_validator(validator_name)
	entries = load_entries(entries_path)
	sample = build_sample(entries, total_sample, random_seed)
	done = load_done_keys(output_path)
	pending = [e for e in sample if !((e.page, e.source_line) in done)]
	to_process = first(pending, group_size)
	prior_cost = load_prior_cost(output_path)

	println("Prompt:        $prompt_path")
	println("Validator:     $validator_name")
	println("Entries:       $entries_path")
	println("Output:        $output_path")
	println("Closed sets:   languages=$(length(closed_sets.languages)), hedges=$(length(closed_sets.hedges)), shapes=$(length(closed_sets.xref_shapes))")
	println("Sample size:   $total_sample (seed $random_seed)")
	println("Already done:  $(length(done))")
	println("Pending:       $(length(pending))")
	println("This group:    $(length(to_process))")
	println("Prior cost:    \$$(round(prior_cost, digits = 4))")
	println()

	group_cost = 0.0
	group_failures = 0
	open(output_path, "a") do output_io
		for (index, entry) in enumerate(to_process)
			try
				record, summary = process_entry(
					entry, system_prompt, validator, closed_sets, output_io,
				)
				group_cost += record.cost
				schema_marker = summary.schema_ok ? "" : " SCHEMA_FAIL"
				println(
					"[$index/$(length(to_process))] $(entry.headword_raw) (p$(entry.page)): " *
					"ety=$(summary.etymologies_valid)/$(summary.etymologies_total) " *
					"cit=$(summary.citations_valid)/$(summary.citations_total) " *
					"xref=$(summary.cross_references_valid)/$(summary.cross_references_total) " *
					"cost=\$$(round(record.cost, digits = 4))$schema_marker",
				)
			catch error
				group_failures += 1
				@warn "extraction failed" headword = entry.headword_raw page = entry.page exception = error
			end
		end
	end

	println()
	println("Group cost:       \$$(round(group_cost, digits = 4))")
	println("Cumulative cost:  \$$(round(prior_cost + group_cost, digits = 4))")
	if group_failures > 0
		println("Failures:         $group_failures (will retry on next run)")
	end
	completed = length(done) + length(to_process) - group_failures
	println("Progress:         $completed / $total_sample")
end

main(parse_args(build_settings()))

