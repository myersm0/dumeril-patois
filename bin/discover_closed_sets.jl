using DumerilPatois
using DumerilPatois: discover_closed_sets, write_discovered_closed_sets

entries_path = "build/entries.md"
output_path = "build/discovered_closed_sets.toml"

pos_counts, region_counts = discover_closed_sets(entries_path)
mkpath(dirname(output_path))
write_discovered_closed_sets(output_path, pos_counts, region_counts)

println("Discovered $(length(pos_counts)) POS surface forms.")
println("Discovered $(length(region_counts)) region surface forms.")
println("Output: $(output_path)")
