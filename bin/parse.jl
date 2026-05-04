using DumerilPatois
using DumerilPatois: parse_entries, load_closed_sets, entry_to_dict, Standard, Locution, Unclassified
using JSON3

entries_path = "build/entries.md"
closed_sets_path = "config/closed_sets.toml"
output_path = "build/entries.jsonl"

closed_sets = load_closed_sets(closed_sets_path)
text = read(entries_path, String)
entries = parse_entries(text, closed_sets)

mkpath(dirname(output_path))
open(output_path, "w") do io
	for entry in entries
		JSON3.write(io, entry_to_dict(entry))
		println(io)
	end
end

standard_count = count(e -> e.kind isa Standard, entries)
locution_count = count(e -> e.kind isa Locution, entries)
unclassified_count = count(e -> e.kind isa Unclassified, entries)

println("Parsed $(length(entries)) entries.")
println("  Standard:     $(standard_count)")
println("  Locution:     $(locution_count)")
println("  Unclassified: $(unclassified_count)")
println("Output: $(output_path)")
